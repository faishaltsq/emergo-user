import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emergo/providers/contacts_provider.dart';
import 'package:emergo/widgets/app_bar_widget.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _addContact() {
    if (_formKey.currentState?.validate() ?? false) {
      Provider.of<ContactsProvider>(context, listen: false).addContact(
        _nameController.text,
        _phoneController.text,
      );
      _nameController.clear();
      _phoneController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Emergency Contacts'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add contact form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Add New Contact',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Contact'),
                          onPressed: _addContact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Contacts list
            Expanded(
              child: Consumer<ContactsProvider>(
                builder: (ctx, contactsProvider, _) {
                  final contacts = contactsProvider.contacts;
                  
                  if (contacts.isEmpty) {
                    return const Center(
                      child: Text('No contacts added yet'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (ctx, index) {
                      final contact = contacts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      contact.phone,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Switch(
                                          value: contact.autoNotify,
                                          onChanged: (_) => contactsProvider.toggleAutoNotify(contact.id),
                                          activeColor: Theme.of(context).primaryColor,
                                        ),
                                        const Text('Auto-notify on SOS'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: () => contactsProvider.deleteContact(contact.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}