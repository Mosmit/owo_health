const functions = require("firebase-functions");
// const admin = require("firebase-admin"); // <-- Comment out
// const { GoogleGenerativeAI } = require("@google/generative-ai"); // <-- Comment out

// Initialize Firebase Admin SDK
// admin.initializeApp(); // <-- Comment out

// Access the AI API key using the FREE functions.config() method
// const API_KEY = functions.config().gemini.key; // <-- Comment out
// if (!API_KEY) {
//  console.error("Gemini API key not set...");
// }

/**
 * Cloud Function for the simple Chat Bot.
 */
exports.getChatResponse = functions.https.onCall(async (data, context) => {
  console.log("getChatResponse called with data:", data); // Add a log
  // Temporarily return a simple response
  return "Chat response placeholder";

  /* --- Original Code ---
  if (!API_KEY) { ... }
  ... rest of your original chat function code ...
  --- */
});


/**
 * Cloud Function for the Symptom Checker.
 */
exports.checkSymptoms = functions.https.onCall(async (data, context) => {
  console.log("checkSymptoms called with data:", data); // Add a log
   // Temporarily return a simple response
  return { message: "Symptom check placeholder" };

  /* --- Original Code ---
  if (!API_KEY) { ... }
  ... rest of your original symptom function code ...
  --- */
});