// supabase/functions/ai-suggestions/index.ts

// Corrected: Import Supabase client from JSR
import { createClient, SupabaseClient } from "@supabase/supabase-js";
// Corrected: Use the Deno-style URL import for OpenAI
import { OpenAI } from "@openai/openai" // Ensure this version is suitable

// Note: The global initialization of 'openai' using 'Configuration' has been removed
// as it's for an older version of the OpenAI library and not needed for the v4 style.
// The OpenAI client will be initialized inside Deno.serve after fetching env vars.

// Define the expected structure for a suggestion from OpenAI
interface AISuggestion {
  name: string;
  description: string;
  price: number;
  billing_cycle: "Monthly" | "Yearly" | "monthly" | "yearly" | "Weekly" | "weekly";
}

// Helper to validate the structure of AI suggestions
function isValidAISuggestionArray(data: any): data is AISuggestion[] {
  if (!Array.isArray(data)) {
    console.warn("isValidAISuggestionArray: Data is not an array.", data);
    return false;
  }
  for (const item of data) {
    if (
      typeof item !== "object" ||
      item === null ||
      typeof item.name !== "string" ||
      typeof item.description !== "string" ||
      typeof item.price !== "number" ||
      (item.billing_cycle?.toLowerCase() !== "monthly" &&
        item.billing_cycle?.toLowerCase() !== "yearly")
    ) {
      console.warn("isValidAISuggestionArray: Invalid item structure.", item);
      return false;
    }
  }
  return true;
}

// Function to insert suggestions into the Supabase table
async function saveSuggestionsToSupabase(
  supabase: SupabaseClient,
  userId: string,
  suggestions: AISuggestion[]
) {
  const suggestionsToInsert = suggestions.map((s) => ({
    user_id: userId,
    name: s.name,
    description: s.description,
    price: s.price,
    billing_cycle:
      s.billing_cycle.toLowerCase() === "monthly" ? "Monthly" : "Yearly",
  }));

  console.log(
    "Attempting to save suggestions to Supabase:",
    suggestionsToInsert
  );
  const { data, error } = await supabase
    .from("suggestions")
    .insert(suggestionsToInsert)
    .select();

  if (error) {
    console.error("Error saving suggestions to Supabase:", error);
    throw new Error(`Failed to save suggestions: ${error.message}`);
  }
  console.log("Suggestions saved to Supabase:", data);
  return data;
}

Deno.serve(async (req: Request) => {
  try {
    // 1. Get Environment Variables
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");

    if (!supabaseUrl || !supabaseServiceRoleKey || !openaiApiKey) {
      console.error(
        "Missing one or more environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, OPENAI_API_KEY."
      );
      return new Response(
        JSON.stringify({ error: "Server configuration error." }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // 2. Initialize Clients
    // Correctly uses the imported 'createClient' from JSR
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
    // Correctly initializes OpenAI v4 style using the class from the URL import
    const openai = new OpenAI({ apiKey: openaiApiKey });

    // 3. Get user_id from request
    if (req.headers.get("content-type") !== "application/json") {
      console.warn("Request content-type is not application/json");
      return new Response(
        JSON.stringify({ error: "Request body must be JSON." }),
        {
          status: 415, // Unsupported Media Type
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    let userId: string;
    try {
      const body = await req.json();
      userId = body.user_id;
      if (!userId || typeof userId !== "string") {
        console.warn("user_id is missing or invalid in request body:", body);
        throw new Error("user_id is missing or invalid in request body.");
      }
    } catch (jsonError) {
      console.error("Error parsing request JSON:", jsonError);
      return new Response(
        JSON.stringify({
          error: `Invalid JSON in request body: ${(jsonError as Error).message}`,
        }),
        {
          status: 400, // Bad Request
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // 4. Fetch existing subscriptions for the user
    console.log(`Fetching subscriptions for user_id: ${userId}`);
    const { data: userSubscriptions, error: subError } = await supabase
      .from("subscriptions")
      .select("name")
      .eq("user_id", userId);

    if (subError) {
      console.error("Supabase query error fetching subscriptions:", subError);
      return new Response(
        JSON.stringify({
          error: `Database error fetching subscriptions: ${subError.message}`,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
    console.log("Subscriptions fetched:", userSubscriptions);
    const subscriptionNames =
      userSubscriptions?.map((s: { name: string }) => s.name).join(", ") ||
      "none";

    // 5. Construct Prompt for OpenAI
    const prompt = `The user currently subscribes to the following services: ${subscriptionNames}.
Based on this, suggest 3 new useful digital subscriptions that complement their existing ones or align with common interests.
Return them strictly in JSON array format like this, with no other text before or after the array:
[
  {
    "name": "Example Service Name 1",
    "description": "A brief description of what this service offers and why it's useful.",
    "price": 12.99,
    "billing_cycle": "Monthly"
  },
  {
    "name": "Example Service Name 2",
    "description": "Another service description.",
    "price": 7.50,
    "billing_cycle": "Monthly"
  },
  {
    "name": "Example Service Name 3",
    "description": "Yearly service description.",
    "price": 79.99,
    "billing_cycle": "Yearly"
  }
]`;

    // 6. Call OpenAI API with JSON Mode
    console.log("Sending prompt to OpenAI...");
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.7,
      response_format: { type: "json_object" },
    });

    console.log("OpenAI API response received.");
    const textResponse = completion.choices[0]?.message?.content;

    if (!textResponse) {
      console.error("No content in AI response.");
      return new Response(
        JSON.stringify({ error: "AI did not return any content." }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
    console.log("AI Response Text (expecting JSON string):", textResponse);

    // 7. Parse and Validate AI response
    let generatedSuggestions: AISuggestion[];
    try {
      const parsedResponse = JSON.parse(textResponse);
      const suggestionsArray = Array.isArray(parsedResponse)
        ? parsedResponse
        : parsedResponse.suggestions || [];

      if (!isValidAISuggestionArray(suggestionsArray)) {
        console.error(
          "AI response is not a valid suggestion array or has incorrect structure:",
          suggestionsArray
        );
        throw new Error("AI returned data in an unexpected format.");
      }
      generatedSuggestions = suggestionsArray;
    } catch (parseError) {
      console.error("Error parsing AI JSON response:", (parseError as Error).message);
      console.error("Raw AI text was:", textResponse);
      return new Response(
        JSON.stringify({
          error: `Failed to parse AI response: ${(parseError as Error).message}`,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    console.log("Parsed AI Suggestions:", generatedSuggestions);

    // 8. OPTIONAL: Save suggestions to Supabase 'suggestions' table
    // --- UNCOMMENT THE FOLLOWING BLOCK TO SAVE SUGGESTIONS ---
    
    try {
      console.log(`Saving ${generatedSuggestions.length} suggestions for user ${userId}...`);
      await saveSuggestionsToSupabase(supabase, userId, generatedSuggestions);
      console.log("Successfully saved suggestions to the database.");
    } catch (saveError) {
      console.error("Error during saveSuggestionsToSupabase:", saveError);
      // Decide if you want to return an error to the client if saving fails,
      // or if you still want to return the generated suggestions.
      // For now, we'll let the error propagate to the main catch block if saving is critical.
      throw saveError; 
    }
    
    // --- END OF SAVE SUGGESTIONS BLOCK ---

    // 9. Return the generated (and potentially saved) suggestions
    return new Response(JSON.stringify({ suggestions: generatedSuggestions }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error(
      "Unhandled error in AI Suggestion Edge Function:",
      (err instanceof Error ? err.message : "Unknown error"),
      err instanceof Error ? err.stack : "No stack available"
    );
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : "An internal server error occurred.",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

console.log(
  "AI Suggestions Edge Function script parsed. Ready to serve requests."
);
