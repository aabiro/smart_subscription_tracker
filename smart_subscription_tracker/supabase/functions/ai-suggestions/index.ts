// supabase/functions/ai-suggestions/index.ts

// Use Deno's built-in serve for HTTP handling
// No specific import needed for Deno.serve itself

// Import Supabase client from JSR (if needed for admin tasks, not used in this version
// as user_id and subscriptions are passed in the request body)
// import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@^2";

// Use a Deno-compatible OpenAI library. Ensure the version is current.
import { OpenAI } from "https://deno.land/x/openai@v4.68.1/mod.ts"; // Or a more recent stable version

// Define the structure of a single suggestion expected from OpenAI
interface AISuggestionItem {
  name: string;
  description: string;
  price: number;
  billing_cycle: "Monthly" | "Yearly"; // Stricter typing
}

// Define the structure of the JSON object OpenAI should return
interface OpenAIResponseFormat {
  suggestions: AISuggestionItem[];
}

console.log("AI Suggestions Edge Function initializing...");

Deno.serve(async (req: Request) => {
  console.log(`Request received: ${req.method} ${req.url}`);

  // CORS Headers - adjust as necessary for your security requirements
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*", // Or your specific Flutter app's domain in production
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS", // Allow OPTIONS for preflight
  };

  // Handle OPTIONS request for CORS preflight
  if (req.method === "OPTIONS") {
    console.log("Handling OPTIONS preflight request.");
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Check Content-Type
    const contentType = req.headers.get("content-type");
    if (
      !contentType ||
      !contentType.toLowerCase().startsWith("application/json")
    ) {
      console.warn(`Invalid Content-Type: ${contentType}`);
      return new Response(
        JSON.stringify({
          error:
            "Request body must be JSON and Content-Type header must be application/json.",
        }),
        {
          status: 415,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 2. Get Environment Variables
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    // const supabaseUrl = Deno.env.get("SUPABASE_URL"); // Not strictly needed if not making new client
    // const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); // Not strictly needed

    if (!openaiApiKey) {
      console.error("Missing OPENAI_API_KEY environment variable.");
      return new Response(
        JSON.stringify({
          error: "Server configuration error: Missing OpenAI API Key.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Initialize OpenAI Client
    const openai = new OpenAI({ apiKey: openaiApiKey });

    // 4. Parse Request Body
    let payload: {
      user_id: string;
      subscriptions?: string[]; // Optional, as per your prompt
      interests: string[];
      budget: number;
      country: string;
    };

    try {
      payload = await req.json();
      console.log("Received payload:", payload);
    } catch (jsonError) {
      console.error("Error parsing request JSON:", jsonError);
      return new Response(
        JSON.stringify({
          error: `Invalid JSON in request body: ${(jsonError as Error).message}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 5. Validate Payload
    const { user_id, subscriptions, interests, budget, country } = payload;
    if (
      !user_id ||
      typeof user_id !== "string" ||
      !Array.isArray(interests) ||
      interests.length === 0 ||
      typeof budget !== "number" ||
      !country ||
      typeof country !== "string"
    ) {
      console.warn(
        "Invalid request payload structure or missing fields:",
        payload
      );
      return new Response(
        JSON.stringify({
          error:
            "Invalid request payload. Required fields: user_id (string), interests (array), budget (number), country (string).",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 6. Construct Prompt for OpenAI
    const currentSubsString =
      subscriptions && subscriptions.length > 0
        ? subscriptions.join(", ")
        : "None";
    const interestsString = interests.join(", ");

    // Updated prompt to ask for a JSON object with a "suggestions" key
    const userPromptContent = `User ID: ${user_id}
Current subscriptions: ${currentSubsString}
Interests: ${interestsString}
Budget for new subscriptions: $${budget} per month
Country: ${country}

Based on ALL this information, suggest 3 new useful digital subscriptions that complement their existing ones or align with their interests, budget, and country.
Return your response as a single JSON object with one top-level key "suggestions". The value of "suggestions" must be an array of 3 subscription objects. Each subscription object should have "name" (string), "description" (string, a short one-line explanation of why this is recommended for this user), "price" (number, estimated monthly price), and "billing_cycle" (string, either "Monthly" or "Yearly").
Example of the exact structure:
{
  "suggestions": [
    {
      "name": "Example Subscription 1",
      "description": "Recommended because it aligns with interest X and fits the budget.",
      "price": 9.99,
      "billing_cycle": "Monthly"
    },
    {
      "name": "Example Subscription 2",
      "description": "Complements current subscription Y.",
      "price": 14.00,
      "billing_cycle": "Monthly"
    },
    {
      "name": "Example Subscription 3",
      "description": "Good value for users in Z country.",
      "price": 99.00,
      "billing_cycle": "Yearly"
    }
  ]
}
Ensure the output is ONLY this JSON object and nothing else.`;

    const messages: { role: "system" | "user"; content: string }[] = [
      {
        role: "system",
        content:
          "You are a helpful recommendation assistant. You must respond with a valid JSON object that has a single key 'suggestions', where the value is an array of subscription objects as specified by the user. Do not include any other text, explanations, or markdown formatting outside of this JSON object.",
      },
      {
        role: "user",
        content: userPromptContent,
      },
    ];

    // 7. Call OpenAI API
    console.log("Sending request to OpenAI API...");
    const completion = await openai.chat.completions.create({
      model: "gpt-4o", // Or gpt-3.5-turbo if it's a newer version supporting JSON mode
      messages: messages,
      temperature: 0.7,
      response_format: { type: "json_object" }, // Crucial for reliable JSON output
    });

    const choice = completion.choices[0];
    const aiContent = choice?.message?.content;
    console.log("OpenAI raw response content:", aiContent);

    if (!aiContent) {
      console.error("OpenAI response content is null or empty.");
      return new Response(
        JSON.stringify({ error: "Failed to get a valid response from AI." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 8. Parse and Validate OpenAI's JSON Response
    let parsedOpenAIResponse: OpenAIResponseFormat;
    try {
      parsedOpenAIResponse = JSON.parse(aiContent);
      // Further validation if needed, e.g. checking if parsedOpenAIResponse.suggestions is an array
      if (
        !parsedOpenAIResponse.suggestions ||
        !Array.isArray(parsedOpenAIResponse.suggestions)
      ) {
        console.error(
          "Parsed OpenAI response does not contain a 'suggestions' array:",
          parsedOpenAIResponse
        );
        throw new Error("AI response does not contain a 'suggestions' array.");
      }
      // You could add more validation here for each item in parsedOpenAIResponse.suggestions
      // to ensure they match AISuggestionItem structure, but for now, we assume the model follows the prompt.
    } catch (e) {
      console.error(
        "Failed to parse OpenAI response as JSON or validate structure:",
        (e as Error).message
      );
      console.error("Problematic AI content:", aiContent);
      return new Response(
        JSON.stringify({
          error: "Failed to parse or validate AI response.",
          details: (e as Error).message,
          raw_ai_response: aiContent,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 9. OPTIONAL: Save suggestions to your Supabase 'suggestions' table
    // (Your previous Deno function had logic for this, uncomment and adapt if needed)
    /*
    const supabaseAdminClient = createClient(supabaseUrl!, supabaseServiceRoleKey!);
    try {
      console.log(`Saving ${parsedOpenAIResponse.suggestions.length} suggestions for user ${user_id}...`);
      await saveSuggestionsToSupabase(supabaseAdminClient, user_id, parsedOpenAIResponse.suggestions); // You'd need to define saveSuggestionsToSupabase
      console.log("Successfully saved suggestions to the database.");
    } catch (saveError) {
      console.error("Error during saveSuggestionsToSupabase:", saveError);
      // Decide if this should be a fatal error for the function call
    }
    */

    // 10. Return the suggestions in the format expected by the Flutter app
    // The Flutter app expects {"suggestions": [...]}
    console.log("Successfully processed request. Returning suggestions.");
    return new Response(JSON.stringify(parsedOpenAIResponse), {
      // parsedOpenAIResponse already has the {"suggestions": [...]} structure
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    if (err instanceof Error) {
      console.error("Unhandled error in Edge Function:", err.message, err.stack);
    } else {
      console.error("Unhandled error in Edge Function:", err);
    }
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "An unexpected server error occurred.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
