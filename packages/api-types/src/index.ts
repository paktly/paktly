export type ApiError = {
  error: {
    code: string;
    message: string;
    requestId: string;
  };
};

export type HealthResponse = {
  service: "paktly-api";
  status: "ok";
  timestamp: string;
  version: string;
};
