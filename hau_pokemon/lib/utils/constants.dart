class AppConstants {
  // CRITICAL: Replace this with your partner's PARIS EC2 Tailscale IP.
  // Because NGINX is routing /api to the Python container, keep the /api suffix.
  static const String backendApiUrl = 'http://100.111.123.17/api'; 
  
  // Paris EC2 Switch API (API Gateway / Lambda)
  // IMPORTANT: API Gateway usually requires a stage and route, e.g.
  //   https://<id>.execute-api.<region>.amazonaws.com/prod/status
  // If you only use the base host, you may get HTTP 404.
  static const String lambdaBaseUrl = 'https://e91iah2ug3.execute-api.eu-west-3.amazonaws.com';

  // Set these to the exact routes your API exposes.
  // Examples:
  //   '$lambdaBaseUrl/prod/status'
  //   '$lambdaBaseUrl/prod/toggle'
  // Current configured route (HTTP API stage + route)
  // Provided by user: https://e91iah2ug3.execute-api.eu-west-3.amazonaws.com/default/EC2ToggleFunction
  static const String lambdaStatusUrl = '$lambdaBaseUrl/default/EC2ToggleFunction';
  static const String lambdaToggleUrl = '$lambdaBaseUrl/default/EC2ToggleFunction';
} 