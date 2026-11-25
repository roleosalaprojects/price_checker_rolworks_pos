import 'package:flutter/material.dart';

import '../services/fingerprint/kiosk_terminal.dart';
import '../pages/fingerprint/higher_access_dialog.dart';
import 'package:price_checker/components/custom_text_field.dart';
import 'package:price_checker/controllers/main_controller.dart';

import '../components/custom_text.dart';
import '../services/http_service.dart';
import 'theme_controller.dart';

const Color appColor = Color(0xFFf48d92);

List<dynamic> products = [];

void showDialogAlert(BuildContext context, String msg) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Padding(
          padding: const EdgeInsets.all(25.0),
          child: CustomText(
            content: msg,
            fontSize: 40,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(appColor),
              textStyle: WidgetStateProperty.all<TextStyle>(
                const TextStyle(color: Colors.white70),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CustomText(content: "Search Again", fontSize: 30),
            ),
          ),
        ],
      );
    },
  );
}

/// The gear (2026-11-25): a registered kiosk whose server answers asks a
/// manager first (higher access, the Settings switch). Not registered yet,
/// or the server out of reach: Settings opens as before, so the address and
/// the registration can always be fixed.
Future<void> openSettingsGuarded(BuildContext context) async {
  if (KioskTerminal.registered && await KioskTerminal.serverAnswers()) {
    if (!context.mounted) return;
    final KioskGrant? grant = await askHigherAccess(context, purpose: 'settings');
    if (grant == null) return;
  }
  if (context.mounted) await promptHostDialog(context);
}

Future<void> promptHostDialog(BuildContext context) {
  final hostController = TextEditingController(text: host);
  final storeController = TextEditingController(text: currentStoreId.toString());
  final managerEmail = TextEditingController();
  final managerPassword = TextEditingController();
  bool fpEnabled = fingerprintEnabled;
  bool registering = false;
  String? fpMessage = KioskTerminal.registered
      ? 'Registered as ${KioskTerminal.name ?? 'this kiosk'}.'
      : 'Not registered: a manager with the Fingerprints switch registers it once.';
  return showDialog(
    context: context,
    builder: (BuildContext subContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CustomText(
                  content: 'Settings',
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    foregroundColor: ThemeController.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CustomText(
                    content: 'Server Host',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: hostController,
                    hintText: 'e.g., 192.168.1.100:8080',
                    onSubmitted: (value) {
                      host = hostController.text;
                      saveServerIP(hostController.text);
                    },
                  ),
                  const SizedBox(height: 16),
                  const CustomText(
                    content: 'Store ID',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: storeController,
                    hintText: 'e.g., 1',
                    keyboardType: TextInputType.number,
                    onSubmitted: (value) {
                      final branchId = int.tryParse(storeController.text) ?? 1;
                      saveStoreId(branchId);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: CustomText(
                          content: 'Fingerprint Attendance',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: fpEnabled,
                        activeThumbColor: appColor,
                        onChanged: (value) {
                          setDialogState(() => fpEnabled = value);
                        },
                      ),
                    ],
                  ),
                  if (fpEnabled) ...[
                    const SizedBox(height: 4),
                    CustomText(content: fpMessage ?? '', fontSize: 13.0),
                    const SizedBox(height: 8),
                    CustomTextField(controller: managerEmail, hintText: 'Manager e-mail'),
                    const SizedBox(height: 8),
                    CustomTextField(controller: managerPassword, hintText: 'Password', obscureText: true),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: registering
                            ? null
                            : () async {
                                // The store and server typed above are the kiosk's.
                                host = hostController.text;
                                saveServerIP(hostController.text);
                                final int storeId = int.tryParse(storeController.text) ?? currentStoreId;
                                saveStoreId(storeId);
                                setDialogState(() => registering = true);
                                Map<String, dynamic> answer = await KioskTerminal.register(
                                  email: managerEmail.text,
                                  password: managerPassword.text,
                                  deviceUuid: kioskDeviceUuid(),
                                  storeId: storeId,
                                );
                                if (answer['code'] == 'replace_needed') {
                                  answer = await KioskTerminal.register(
                                    email: managerEmail.text,
                                    password: managerPassword.text,
                                    deviceUuid: kioskDeviceUuid(),
                                    storeId: storeId,
                                    replace: true,
                                  );
                                }
                                managerPassword.clear();
                                setDialogState(() {
                                  registering = false;
                                  fpMessage = answer['status'] == 200
                                      ? 'Registered as ${KioskTerminal.name ?? 'this kiosk'}.'
                                      : '${answer['message'] ?? 'Not registered.'}';
                                });
                              },
                        child: Text(registering ? 'Registering…' : 'Register this kiosk'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const CustomText(
                    content: 'Theme',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          _buildThemeOption(
                            context: context,
                            label: 'Light',
                            icon: Icons.light_mode_outlined,
                            isSelected: themeController!.themeMode == ThemeMode.light,
                            onTap: () {
                              themeController!.setThemeMode(ThemeMode.light);
                              setDialogState(() {});
                            },
                          ),
                          _buildThemeOption(
                            context: context,
                            label: 'Dark',
                            icon: Icons.dark_mode_outlined,
                            isSelected: themeController!.themeMode == ThemeMode.dark,
                            onTap: () {
                              themeController!.setThemeMode(ThemeMode.dark);
                              setDialogState(() {});
                            },
                          ),
                          _buildThemeOption(
                            context: context,
                            label: 'System',
                            icon: Icons.settings_suggest_outlined,
                            isSelected: themeController!.themeMode == ThemeMode.system,
                            onTap: () {
                              themeController!.setThemeMode(ThemeMode.system);
                              setDialogState(() {});
                            },
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      host = hostController.text;
                      saveServerIP(hostController.text);
                      final branchId = int.tryParse(storeController.text) ?? 1;
                      saveStoreId(branchId);
                      saveFingerprintEnabled(fpEnabled);
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildThemeOption({
  required BuildContext context,
  required String label,
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
  bool isLast = false,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? appColor.withValues(alpha: 0.15)
              : Colors.transparent,
          border: isLast
              ? null
              : Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? appColor
                  : ThemeController.getSecondaryTextColor(context),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? appColor
                    : ThemeController.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
