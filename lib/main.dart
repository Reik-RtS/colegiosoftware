import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Colegio - Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginPage(authService: _authService);
        }

        return HomePage(authService: _authService, user: user);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  bool _loading = false;
  bool _sendingSms = false;
  bool _verifyingSms = false;
  String? _verificationId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await widget.authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      final message = error.message ?? 'No se pudo iniciar sesión';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      await widget.authService.signInWithGoogle();
      if (!mounted) return;
      await _requestStudentInfoDialog();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No se pudo iniciar con Google')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendSmsCode() async {
    setState(() {
      _sendingSms = true;
      _verificationId = null;
    });
    try {
      final verificationId =
          await widget.authService.sendSmsCode(_phoneController.text.trim());
      if (!mounted) return;
      _verificationId = verificationId.isEmpty ? null : verificationId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verificationId.isEmpty
                ? 'Autenticación por SMS completada automáticamente'
                : 'Código enviado, revisa tu SMS',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No se pudo enviar el código')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingSms = false);
      }
    }
  }

  Future<void> _confirmSmsCode() async {
    if (_verificationId == null || _smsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el código SMS que recibiste')),
      );
      return;
    }

    setState(() => _verifyingSms = true);
    try {
      await widget.authService.signInWithSmsCode(
        verificationId: _verificationId!,
        smsCode: _smsController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión iniciada con SMS')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Código inválido')),
      );
    } finally {
      if (mounted) {
        setState(() => _verifyingSms = false);
      }
    }
  }

  Future<void> _requestStudentInfoDialog() async {
    await showDialog<StudentInfoData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const StudentInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Acceso al sistema'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ingresar'),
              Tab(text: 'Registrar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LoginTab(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              loading: _loading,
              onLogin: _handleLogin,
              onGoogleLogin: _handleGoogleSignIn,
              onSendSms: _sendSmsCode,
              onVerifySms: _confirmSmsCode,
              phoneController: _phoneController,
              smsController: _smsController,
              sendingSms: _sendingSms,
              verifyingSms: _verifyingSms,
              smsSent: _verificationId != null,
            ),
            _RegisterTab(authService: widget.authService),
          ],
        ),
      ),
    );
  }
}

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.onSendSms,
    required this.onVerifySms,
    required this.phoneController,
    required this.smsController,
    required this.sendingSms,
    required this.verifyingSms,
    required this.smsSent,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController phoneController;
  final TextEditingController smsController;
  final bool loading;
  final bool sendingSms;
  final bool verifyingSms;
  final bool smsSent;
  final VoidCallback onLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onSendSms;
  final VoidCallback onVerifySms;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!value.contains('@')) {
                          return 'Correo inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña';
                        }
                        if (value.length < 6) {
                          return 'Debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : onLogin,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Ingresar'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('o'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  onPressed: loading ? null : onGoogleLogin,
                  label: const Text('Ingresar con Google'),
                ),
              ),
              const SizedBox(height: 16),
              _PhoneLoginSection(
                phoneController: phoneController,
                smsController: smsController,
                sendingSms: sendingSms,
                verifyingSms: verifyingSms,
                smsSent: smsSent,
                onSendSms: onSendSms,
                onVerifySms: onVerifySms,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneLoginSection extends StatelessWidget {
  const _PhoneLoginSection({
    required this.phoneController,
    required this.smsController,
    required this.sendingSms,
    required this.verifyingSms,
    required this.smsSent,
    required this.onSendSms,
    required this.onVerifySms,
  });

  final TextEditingController phoneController;
  final TextEditingController smsController;
  final bool sendingSms;
  final bool verifyingSms;
  final bool smsSent;
  final VoidCallback onSendSms;
  final VoidCallback onVerifySms;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accede con número y código SMS',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Número de teléfono',
                prefixIcon: Icon(Icons.phone),
                hintText: '+51 999 999 999',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: sendingSms ? null : onSendSms,
                    child: sendingSms
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar código'),
                  ),
                ),
              ],
            ),
            if (smsSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: smsController,
                decoration: const InputDecoration(
                  labelText: 'Código SMS',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: verifyingSms ? null : onVerifySms,
                  child: verifyingSms
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar código y acceder'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegisterTab extends StatefulWidget {
  const _RegisterTab({required this.authService});

  final AuthService authService;

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<StudentInfoFormState> _studentInfoKey =
      GlobalKey<StudentInfoFormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final info = _studentInfoKey.currentState?.validateAndBuild();
    if (info == null) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registro completado para ${info.nombre} ${info.apellidos}',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'No se pudo registrar')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crear cuenta y datos del estudiante',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!value.contains('@')) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una contraseña';
                          }
                          if (value.length < 6) {
                            return 'Debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma tu contraseña';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StudentInfoForm(key: _studentInfoKey),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: _loading ? null : _register,
                  label: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrar y guardar datos'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class StudentInfoDialog extends StatefulWidget {
  const StudentInfoDialog({super.key});

  @override
  State<StudentInfoDialog> createState() => _StudentInfoDialogState();
}

class _StudentInfoDialogState extends State<StudentInfoDialog> {
  final GlobalKey<StudentInfoFormState> _infoKey =
      GlobalKey<StudentInfoFormState>();
  bool _saving = false;

  Future<void> _submit() async {
    final data = _infoKey.currentState?.validateAndBuild();
    if (data == null) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirma tus datos de estudiante'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: StudentInfoForm(key: _infoKey),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar y continuar'),
        ),
      ],
    );
  }
}

class StudentInfoData {
  const StudentInfoData({
    required this.studentId,
    required this.nombre,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.dniEstudiante,
    required this.sexo,
    required this.direccion,
    required this.telefonoEmergencia,
    required this.correo,
    required this.padreNombre,
    required this.padreDni,
    required this.padreTelefono,
    required this.padreCorreo,
    required this.padreRelacion,
    required this.padreOcupacion,
    required this.madreNombre,
    required this.madreDni,
    required this.madreTelefono,
    required this.madreCorreo,
    required this.madreRelacion,
    required this.madreOcupacion,
    required this.grado,
    required this.seccion,
    required this.turno,
    required this.numeroMatricula,
    required this.fechaInscripcion,
    required this.estadoAcademico,
    required this.alergias,
    required this.enfermedades,
    required this.medicamentos,
    required this.seguroMedico,
    required this.montoMatricula,
    required this.cuotas,
    required this.becas,
    required this.fechaPago,
    required this.actividades,
    required this.fechaActividades,
    required this.calificaciones,
    required this.notasComportamiento,
    required this.asistencia,
  });

  final String studentId;
  final String nombre;
  final String apellidos;
  final String fechaNacimiento;
  final String dniEstudiante;
  final String sexo;
  final String direccion;
  final String telefonoEmergencia;
  final String correo;
  final String padreNombre;
  final String padreDni;
  final String padreTelefono;
  final String padreCorreo;
  final String padreRelacion;
  final String padreOcupacion;
  final String madreNombre;
  final String madreDni;
  final String madreTelefono;
  final String madreCorreo;
  final String madreRelacion;
  final String madreOcupacion;
  final String grado;
  final String seccion;
  final String turno;
  final String numeroMatricula;
  final String fechaInscripcion;
  final String estadoAcademico;
  final String alergias;
  final String enfermedades;
  final String medicamentos;
  final String seguroMedico;
  final String montoMatricula;
  final String cuotas;
  final String becas;
  final String fechaPago;
  final String actividades;
  final String fechaActividades;
  final String calificaciones;
  final String notasComportamiento;
  final String asistencia;
}

class StudentInfoForm extends StatefulWidget {
  const StudentInfoForm({super.key});

  @override
  State<StudentInfoForm> createState() => StudentInfoFormState();
}

class StudentInfoFormState extends State<StudentInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _sexoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _telefonoEmergenciaController =
      TextEditingController();
  final TextEditingController _correoController = TextEditingController();

  final TextEditingController _padreNombreController = TextEditingController();
  final TextEditingController _padreDniController = TextEditingController();
  final TextEditingController _padreTelefonoController = TextEditingController();
  final TextEditingController _padreCorreoController = TextEditingController();
  final TextEditingController _padreRelacionController = TextEditingController();
  final TextEditingController _padreOcupacionController = TextEditingController();

  final TextEditingController _madreNombreController = TextEditingController();
  final TextEditingController _madreDniController = TextEditingController();
  final TextEditingController _madreTelefonoController = TextEditingController();
  final TextEditingController _madreCorreoController = TextEditingController();
  final TextEditingController _madreRelacionController = TextEditingController();
  final TextEditingController _madreOcupacionController = TextEditingController();

  final TextEditingController _gradoController = TextEditingController();
  final TextEditingController _seccionController = TextEditingController();
  final TextEditingController _turnoController = TextEditingController();
  final TextEditingController _numeroMatriculaController =
      TextEditingController();
  final TextEditingController _fechaInscripcionController =
      TextEditingController();
  final TextEditingController _estadoAcademicoController =
      TextEditingController();

  final TextEditingController _alergiasController = TextEditingController();
  final TextEditingController _enfermedadesController = TextEditingController();
  final TextEditingController _medicamentosController = TextEditingController();
  final TextEditingController _seguroMedicoController = TextEditingController();

  final TextEditingController _montoMatriculaController =
      TextEditingController();
  final TextEditingController _cuotasController = TextEditingController();
  final TextEditingController _becasController = TextEditingController();
  final TextEditingController _fechaPagoController = TextEditingController();

  final TextEditingController _actividadesController = TextEditingController();
  final TextEditingController _fechaActividadesController =
      TextEditingController();
  final TextEditingController _calificacionesController =
      TextEditingController();
  final TextEditingController _notasComportamientoController =
      TextEditingController();
  final TextEditingController _asistenciaController = TextEditingController();

  @override
  void dispose() {
    _studentIdController.dispose();
    _nombreController.dispose();
    _apellidosController.dispose();
    _fechaNacimientoController.dispose();
    _dniController.dispose();
    _sexoController.dispose();
    _direccionController.dispose();
    _telefonoEmergenciaController.dispose();
    _correoController.dispose();
    _padreNombreController.dispose();
    _padreDniController.dispose();
    _padreTelefonoController.dispose();
    _padreCorreoController.dispose();
    _padreRelacionController.dispose();
    _padreOcupacionController.dispose();
    _madreNombreController.dispose();
    _madreDniController.dispose();
    _madreTelefonoController.dispose();
    _madreCorreoController.dispose();
    _madreRelacionController.dispose();
    _madreOcupacionController.dispose();
    _gradoController.dispose();
    _seccionController.dispose();
    _turnoController.dispose();
    _numeroMatriculaController.dispose();
    _fechaInscripcionController.dispose();
    _estadoAcademicoController.dispose();
    _alergiasController.dispose();
    _enfermedadesController.dispose();
    _medicamentosController.dispose();
    _seguroMedicoController.dispose();
    _montoMatriculaController.dispose();
    _cuotasController.dispose();
    _becasController.dispose();
    _fechaPagoController.dispose();
    _actividadesController.dispose();
    _fechaActividadesController.dispose();
    _calificacionesController.dispose();
    _notasComportamientoController.dispose();
    _asistenciaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    TextEditingController controller,
    String label,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),
      helpText: label,
    );
    if (picked != null) {
      controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  StudentInfoData? validateAndBuild() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;

    return StudentInfoData(
      studentId: _studentIdController.text.trim(),
      nombre: _nombreController.text.trim(),
      apellidos: _apellidosController.text.trim(),
      fechaNacimiento: _fechaNacimientoController.text.trim(),
      dniEstudiante: _dniController.text.trim(),
      sexo: _sexoController.text.trim(),
      direccion: _direccionController.text.trim(),
      telefonoEmergencia: _telefonoEmergenciaController.text.trim(),
      correo: _correoController.text.trim(),
      padreNombre: _padreNombreController.text.trim(),
      padreDni: _padreDniController.text.trim(),
      padreTelefono: _padreTelefonoController.text.trim(),
      padreCorreo: _padreCorreoController.text.trim(),
      padreRelacion: _padreRelacionController.text.trim(),
      padreOcupacion: _padreOcupacionController.text.trim(),
      madreNombre: _madreNombreController.text.trim(),
      madreDni: _madreDniController.text.trim(),
      madreTelefono: _madreTelefonoController.text.trim(),
      madreCorreo: _madreCorreoController.text.trim(),
      madreRelacion: _madreRelacionController.text.trim(),
      madreOcupacion: _madreOcupacionController.text.trim(),
      grado: _gradoController.text.trim(),
      seccion: _seccionController.text.trim(),
      turno: _turnoController.text.trim(),
      numeroMatricula: _numeroMatriculaController.text.trim(),
      fechaInscripcion: _fechaInscripcionController.text.trim(),
      estadoAcademico: _estadoAcademicoController.text.trim(),
      alergias: _alergiasController.text.trim(),
      enfermedades: _enfermedadesController.text.trim(),
      medicamentos: _medicamentosController.text.trim(),
      seguroMedico: _seguroMedicoController.text.trim(),
      montoMatricula: _montoMatriculaController.text.trim(),
      cuotas: _cuotasController.text.trim(),
      becas: _becasController.text.trim(),
      fechaPago: _fechaPagoController.text.trim(),
      actividades: _actividadesController.text.trim(),
      fechaActividades: _fechaActividadesController.text.trim(),
      calificaciones: _calificacionesController.text.trim(),
      notasComportamiento: _notasComportamientoController.text.trim(),
      asistencia: _asistenciaController.text.trim(),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? helper,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obligatorio';
              }
              return null;
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          SectionCard(
            title: 'Datos del estudiante',
            children: [
              _buildField(_studentIdController, 'ID del estudiante',
                  requiredField: true),
              _buildField(_nombreController, 'Nombre', requiredField: true),
              _buildField(_apellidosController, 'Apellido(s)',
                  requiredField: true),
              TextFormField(
                controller: _fechaNacimientoController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _pickDate(
                  _fechaNacimientoController,
                  'Selecciona la fecha de nacimiento',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona la fecha de nacimiento';
                  }
                  return null;
                },
              ),
              _buildField(_dniController, 'DNI del estudiante',
                  requiredField: true,
                  keyboardType: TextInputType.number),
              _buildField(_sexoController, 'Sexo (M/F/Otro)',
                  requiredField: true),
              _buildField(_direccionController, 'Dirección completa',
                  requiredField: true, maxLines: 2),
              _buildField(_telefonoEmergenciaController, 'Teléfono de emergencia',
                  requiredField: true, keyboardType: TextInputType.phone),
              _buildField(_correoController, 'Correo del estudiante o tutor',
                  requiredField: true, keyboardType: TextInputType.emailAddress),
            ],
          ),
          SectionCard(
            title: 'Datos de los padres o tutores',
            children: [
              _buildField(_padreNombreController, 'Nombre del padre/tutor'),
              _buildField(_padreDniController, 'DNI del padre/tutor'),
              _buildField(_padreTelefonoController, 'Teléfono del padre/tutor',
                  keyboardType: TextInputType.phone),
              _buildField(_padreCorreoController, 'Correo del padre/tutor',
                  keyboardType: TextInputType.emailAddress),
              _buildField(
                _padreRelacionController,
                'Relación con el estudiante',
                helper: 'Padre, madre, tutor legal, etc.',
              ),
              _buildField(_padreOcupacionController, 'Ocupación (opcional)'),
              const Divider(height: 24),
              _buildField(_madreNombreController, 'Nombre de la madre/tutora'),
              _buildField(_madreDniController, 'DNI de la madre/tutora'),
              _buildField(
                _madreTelefonoController,
                'Teléfono de la madre/tutora',
                keyboardType: TextInputType.phone,
              ),
              _buildField(
                _madreCorreoController,
                'Correo de la madre/tutora',
                keyboardType: TextInputType.emailAddress,
              ),
              _buildField(
                _madreRelacionController,
                'Relación con el estudiante',
              ),
              _buildField(_madreOcupacionController, 'Ocupación (opcional)'),
            ],
          ),
          SectionCard(
            title: 'Datos académicos',
            children: [
              _buildField(_gradoController, 'Grado o curso', requiredField: true),
              _buildField(_seccionController, 'Sección o grupo'),
              _buildField(_turnoController, 'Turno', helper: 'Mañana, tarde'),
              _buildField(_numeroMatriculaController, 'Número de matrícula',
                  requiredField: true),
              TextFormField(
                controller: _fechaInscripcionController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de inscripción',
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                onTap: () => _pickDate(
                  _fechaInscripcionController,
                  'Selecciona la fecha de inscripción',
                ),
              ),
              _buildField(_estadoAcademicoController, 'Estado académico',
                  helper: 'Activo, egresado, suspendido'),
            ],
          ),
          SectionCard(
            title: 'Datos de salud',
            children: [
              _buildField(_alergiasController, 'Alergias'),
              _buildField(_enfermedadesController, 'Enfermedades preexistentes'),
              _buildField(_medicamentosController, 'Medicamentos'),
              _buildField(_seguroMedicoController, 'Seguro médico y contacto'),
            ],
          ),
          SectionCard(
            title: 'Datos administrativos y financieros',
            children: [
              _buildField(_montoMatriculaController, 'Monto de matrícula',
                  keyboardType: TextInputType.number),
              _buildField(_cuotasController, 'Pago de cuotas'),
              _buildField(_becasController, 'Becas o descuentos'),
              TextFormField(
                controller: _fechaPagoController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de pago',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () => _pickDate(
                  _fechaPagoController,
                  'Selecciona la fecha de pago',
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'Actividades y seguimiento',
            children: [
              _buildField(_actividadesController, 'Actividades extraescolares'),
              TextFormField(
                controller: _fechaActividadesController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de inscripción en actividades',
                  suffixIcon: Icon(Icons.event_available_outlined),
                ),
                onTap: () => _pickDate(
                  _fechaActividadesController,
                  'Selecciona la fecha de inscripción en actividades',
                ),
              ),
              _buildField(_calificacionesController, 'Calificaciones por materia',
                  maxLines: 2),
              _buildField(
                _notasComportamientoController,
                'Notas de comportamiento',
                maxLines: 2,
              ),
              _buildField(_asistenciaController, 'Asistencia o faltas',
                  maxLines: 2),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.authService, required this.user});

  final AuthService authService;
  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel principal'),
        actions: [
          IconButton(
            onPressed: () => authService.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, size: 72, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              'Sesión iniciada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? 'Usuario sin correo',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
