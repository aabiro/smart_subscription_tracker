// No import needed from std/http/server.ts for Deno.serve

async function handler(req: Request): Promise<Response> {
  try {
    const { subscriptions, interests, budget, country, user_id } = await req.json();

    // Basic validation
    if (!subscriptions || !interests || budget === undefined || !country || !user_id) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: subscriptions, interests, budget, country, user_id",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const prompt = `
User currently subscribes to: ${
      Array.isArray(subscriptions) ? subscriptions.join(", ") : subscriptions
    }.
Their interests are: ${
      Array.isArray(interests) ? interests.join(", ") : interests
    }.
Their monthly budget is $${budget} and they are in ${country}.

Suggest 3 relevant and popular subscription services that complement what they already use. Include the name, a brief reason, and the monthly cost. Provide only the suggestions, without any introductory or concluding remarks.`;

    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      console.error("OPENAI_API_KEY is not set in the environment.");
      return new Response(
        JSON.stringify({ error: "OpenAI API key is not configured." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful subscription recommendation assistant. Provide only the raw text of the suggestions.",
          },
          { role: "user", content: prompt },
        ],
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error("OpenAI API error:", response.status, errorData);
      return new Response(
        JSON.stringify({
          error: "Failed to get a response from OpenAI.",
          details: errorData,
        }),
        {
          status: response.status,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const data = await response.json();
    const aiText = data.choices?.[0]?.message?.content?.trim() ?? "";

    // Parse the suggestions (implement your own parser here)
    const parsedSuggestions = parseSuggestions(aiText);

    // Store suggestions in Supabase
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_KEY");

    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      console.error("Supabase environment variables are not set.");
      return new Response(
        JSON.stringify({ error: "Supabase configuration is missing." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    for (const suggestion of parsedSuggestions) {
      await fetch(`${SUPABASE_URL}/rest/v1/suggestions`, {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: user_id,
          name: suggestion.name,
          description: suggestion.description,
          price: suggestion.price,
        }),
      });
    }

    return new Response(JSON.stringify({ suggestions: parsedSuggestions }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error in request handler:", error);
    let errorMessage = "An unexpected error occurred.";
    if (error instanceof SyntaxError && error.message.includes("JSON")) {
      errorMessage = "Invalid JSON in request body.";
      return new Response(JSON.stringify({ error: errorMessage }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(
      JSON.stringify({
        error: errorMessage,
        details: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
}

// Implement your own parser function to parse AI suggestions
function parseSuggestions(aiText: string): Array<{ name: string; description: string; price: number }> {
  // Example parser logic (replace with your own implementation)
  return aiText.split("\n").map((line) => {
    const [name, description, price] = line.split(" - ");
    return {
      name: name.trim(),
      description: description.trim(),
      price: parseFloat(price.replace("$", "").trim()),
    };
  });
}

// Start the Deno server
Deno.serve(handler);
