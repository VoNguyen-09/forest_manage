class EmailJsConfig {
  EmailJsConfig._();

  static const String serviceId = 'service_91avncg';
  static const String templateId = 'template_eevszbp';
  static const String publicKey = 'Upx6rWFnSH2CCRKi2';

  static bool get isConfigured =>
      serviceId != 'YOUR_EMAILJS_SERVICE_ID' &&
      templateId != 'YOUR_EMAILJS_TEMPLATE_ID' &&
      publicKey != 'YOUR_EMAILJS_PUBLIC_KEY';
}
