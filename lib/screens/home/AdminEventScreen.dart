import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _defiIdController = TextEditingController();
  bool _isActive = true;
  bool _loading = false;
  String? _resultMessage;

  Future<void> _createEvent() async {
    final supabase = Supabase.instance.client;

    final defiId = int.tryParse(_defiIdController.text);
    if (defiId == null) {
      setState(() => _resultMessage = "⚠️ L'ID du défi doit être un nombre !");
      return;
    }

    setState(() => _loading = true);

    try {
      // Requête SQL : création d’un event pour aujourd’hui
      await supabase.from('bonus_challenges').insert({
        'defi_id': defiId,
        'date': DateTime.now().toIso8601String().split('T').first, // current date
        'is_active': _isActive,
      });

      setState(() {
        _resultMessage = "✅ Évènement créé avec succès !";
      });
    } catch (e) {
      setState(() {
        _resultMessage = "❌ Erreur lors de la création : $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Créer un évènement"),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Créer un évènement communautaire",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _defiIdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "ID du défi",
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white38),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SwitchListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text(
                "Évènement actif ?",
                style: TextStyle(color: Colors.white),
              ),
              activeColor: const Color.fromARGB(255, 35, 255, 53),
            ),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createEvent,
                icon: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.add),
                label: const Text("Créer l'évènement"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_resultMessage != null)
              Center(
                child: Text(
                  _resultMessage!,
                  style: TextStyle(
                    color: _resultMessage!.startsWith("✅")
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
