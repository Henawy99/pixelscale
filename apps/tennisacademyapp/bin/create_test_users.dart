import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://hdmycuncdlbefiiwlrca.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkbXljdW5jZGxiZWZpaXdscmNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MTQ0NjIsImV4cCI6MjA2NTk5MDQ2Mn0.EqbT-LkOAnr7vOXlX93W5rsNF4HedWJqpvLVdPeu6l0',
  );
  
  final client = Supabase.instance.client;
  
  print('Creating user player@tennis.com...');
  try {
    final response = await client.auth.signUp(
      email: 'player@tennis.com', 
      password: '12345', 
      data: {'full_name': 'Test User'},
    );
    print('User created successfully: \${response.user?.id}');
    
    // Also update role if needed
    if (response.user != null) {
      await client.from('profiles').update({'role': 'player'}).eq('id', response.user!.id);
      print('Profile updated to player role.');
    }
  } catch (e) {
    print('Failed to create user: \$e');
  }
}
