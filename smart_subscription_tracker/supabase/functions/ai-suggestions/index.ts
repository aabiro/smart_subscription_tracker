// supabase/functions/ai-suggestions/index.ts

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@^2";
import { OpenAI } from "https://deno.land/x/openai@v4.68.1/mod.ts"; // Ensure this version is current and suitable

interface AISuggestion {
  name: string;
  description: string;
  price: number;
  billing_cycle: "Monthly" | "Yearly" | "monthly" | "yearly";
}

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

    const supabaseAdminClient = createClient(
      supabaseUrl,
      supabaseServiceRoleKey
    );
    const openai = new OpenAI({ apiKey: openaiApiKey });

    // Log all incoming headers for debugging
    console.log(
      "Incoming request headers:",
      Object.fromEntries(req.headers.entries())
    );

    const contentType = req.headers.get("content-type");
    console.log(`Received Content-Type: '${contentType}'`); // Log the exact content type

    // Make the Content-Type check more robust
    if (
      !contentType ||
      !contentType.toLowerCase().startsWith("application/json")
    ) {
      console.warn(
        `Request content-type is not application/json. Received: '${contentType}'`
      );
      return new Response(
        JSON.stringify({
          error:
            "Request body must be JSON and Content-Type header must be application/json.",
        }),
        {
          status: 415,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    let userIdFromBody: string;
    try {
      const body = await req.json();
      userIdFromBody = body.user_id;
      if (!userIdFromBody || typeof userIdFromBody !== "string") {
        console.warn("user_id is missing or invalid in request body:", body);
        throw new Error("user_id is missing or invalid in request body.");
      }
    } catch (jsonError) {
      console.error("Error parsing request JSON:", jsonError);
      return new Response(
        JSON.stringify({
          error: `Invalid JSON in request body: ${
            jsonError instanceof Error ? jsonError.message : "Unknown error"
          }`,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    console.log(`Fetching subscriptions for user_id: ${userIdFromBody}`);
    const { data: userSubscriptions, error: subError } =
      await supabaseAdminClient
        .from("subscriptions")
        .select("name")
        .eq("user_id", userIdFromBody);

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
      if (parseError instanceof Error) {
        console.error("Error parsing AI JSON response:", parseError.message);
      } else {
        console.error("Error parsing AI JSON response:", parseError);
      }
      console.error("Raw AI text was:", textResponse);
      return new Response(
        JSON.stringify({
          error: `Failed to parse AI response: ${
            parseError instanceof Error ? parseError.message : "Unknown error"
          }`,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
    console.log("Parsed AI Suggestions:", generatedSuggestions);

    // UNCOMMENT TO SAVE SUGGESTIONS
    /*
    try {
      console.log(`Saving ${generatedSuggestions.length} suggestions for user ${userIdFromBody}...`);
      await saveSuggestionsToSupabase(supabaseAdminClient, userIdFromBody, generatedSuggestions);
      console.log("Successfully saved suggestions to the database.");
    } catch (saveError) {
      console.error("Error during saveSuggestionsToSupabase:", saveError);
      throw saveError; 
    }
    */

    return new Response(JSON.stringify({ suggestions: generatedSuggestions }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error(
      "Unhandled error in AI Suggestion Edge Function:",
      err instanceof Error ? err.message : "Unknown error",
      err instanceof Error ? err.stack : "No stack available"
    );
    return new Response(
      JSON.stringify({
        error:
          err instanceof Error
            ? err.message
            : "An internal server error occurred.",
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
