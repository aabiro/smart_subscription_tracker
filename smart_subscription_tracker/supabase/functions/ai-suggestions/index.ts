// File: supabase/functions/ai-suggestions/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const { user_id, subscriptions, interests, budget, country } =
      await req.json();

    const messages = [
      {
        role: "system",
        content:
          "You are a recommendation engine that returns subscription suggestions in JSON only. Do not include any explanation, headers, or notes.",
      },
      {
        role: "user",
        content: `User ID: ${user_id}
Current subscriptions: ${subscriptions.join(", ")}
Interests: ${interests.join(", ")}
Budget: $${budget}
Country: ${country}

Based on this info, return 3 subscription suggestions in the following format as a JSON array only:

[
  {
    "name": "Example Subscription",
    "description": "Short one-line explanation of why this is recommended.",
    "price": 9.99,
    "billing_cycle": "Monthly"
  }
]

Only respond with a JSON array.`,
      },
    ];

    const openaiRes = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        },
        body: JSON.stringify({
          model: "gpt-3.5-turbo",
          messages,
          temperature: 0.7,
        }),
      }
    );

    const raw = await openaiRes.json();

    console.log("Raw OpenAI response:", raw);

    let suggestions = [];
    try {
      const content = raw.choices?.[0]?.message?.content?.trim();
      suggestions = JSON.parse(content);
    } catch (e) {
      console.error("❌ Failed to parse OpenAI response as JSON:", e);
      suggestions = [];
    }

    return new Response(JSON.stringify(suggestions), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("❌ Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Failed to process request" }),
      {
        status: 500,
      }
    );
  }
});
