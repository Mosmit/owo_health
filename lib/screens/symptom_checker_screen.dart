import 'dart:convert'; // Import for JSON decoding
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  _SymptomCheckerScreenState createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _symptomController = TextEditingController();

  bool _loading = false;
  String? _resultText; // This will hold the formatted result for display

  // Get the current user
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _checkSymptoms() async {
    if (_ageController.text.isEmpty ||
        _genderController.text.isEmpty ||
        _symptomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must be logged in.")));
      return;
    }

    setState(() {
      _loading = true;
      _resultText = null;
    });

    // 1. Create the new JSON-based prompt
    final String prompt =
        """
    Analyze the following patient data and provide a response STRICTLY in JSON format. 
    The JSON object must include three keys: 
    1. "causes": (a brief string)
    2. "urgency": (a single string: "low", "moderate", or "emergency")
    3. "recommendations": (a brief string of next steps)
    Keep the language patient-friendly.

    Patient Data:
    - Age: ${_ageController.text}
    - Gender: ${_genderController.text}
    - Symptoms: ${_symptomController.text}
    """;

    try {
      // 2. Call our secure Cloud Function (running on the emulator)
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getAiResponse');
      final response = await callable.call<Map<String, dynamic>>({
        'prompt': prompt,
      });

      // 3. Parse the JSON response from the function
      // Our function returns { "text": "{\"causes\": ...}" }
      final aiJsonString = response.data['text'] as String;
      final aiJsonMap = jsonDecode(aiJsonString) as Map<String, dynamic>;

      // 4. Save the structured data to the user's private collection
      final dataToSave = {
        'age': _ageController.text,
        'gender': _genderController.text,
        'symptoms': _symptomController.text,
        'timestamp': FieldValue.serverTimestamp(),
        // Save the parsed data for easy querying later
        'causes': aiJsonMap['causes'],
        'urgency': aiJsonMap['urgency'],
        'recommendations': aiJsonMap['recommendations'],
      };

      await FirebaseFirestore.instance
          .collection('users') // Base 'users' collection
          .doc(_currentUser!.uid) // The user's specific document
          .collection('symptom_checks') // The user's private sub-collection
          .add(dataToSave);

      // 5. Format the result for display
      setState(() {
        _resultText =
            """
Urgency: ${aiJsonMap['urgency']?.toUpperCase()}

Possible Causes:
${aiJsonMap['causes']}

Recommendations:
${aiJsonMap['recommendations']}
        """;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _resultText = "Error calling AI: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _resultText = "An error occurred: ${e.toString()}";
      });
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We don't need an AppBar here, as HomeScreen provides it.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: "Age"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _genderController,
              decoration: const InputDecoration(labelText: "Gender"),
            ),
            TextField(
              controller: _symptomController,
              decoration: const InputDecoration(
                labelText: "Symptoms (e.g., 'headache, fever')",
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _checkSymptoms,
                    icon: const Icon(Icons.health_and_safety),
                    label: const Text("Check Symptoms"),
                  ),
            const SizedBox(height: 20),
            if (_resultText != null)
              Card(
                color: Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _resultText!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.red[50],
        child: const Text(
          "⚠️ This is an AI assistant and not a substitute for professional medical advice. Please consult a doctor.",
          style: TextStyle(fontSize: 12, color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
