import type { FastifyInstance } from "fastify";
import type { ApiError } from "@pakt/api-types";

/** Explicitly safe messages for operational failures. Never expose arbitrary errors. */
export class PublicAPIError extends Error {
  constructor(readonly statusCode: number, readonly code: string, message: string) { super(message); }
}

export function registerErrorHandling(app: FastifyInstance): void {
  app.setNotFoundHandler((request, reply) => {
    const payload: ApiError = {
      error: {
        code: "NOT_FOUND",
        message: "The requested resource was not found.",
        requestId: request.id
      }
    };

    return reply.status(404).send(payload);
  });

  app.setErrorHandler((error: unknown, request, reply) => {
    const normalizedError = normalizeError(error);
    const statusCode = normalizedError.statusCode;
    const isServerError = statusCode >= 500;

    if (isServerError) {
      request.log.error({ err: normalizedError.cause }, "request failed");
    } else {
      request.log.info({ err: normalizedError.cause }, "request rejected");
    }

    const payload: ApiError = {
      error: {
        code: error instanceof PublicAPIError ? error.code : isServerError ? "INTERNAL_ERROR" : "REQUEST_ERROR",
        message: isServerError && !(error instanceof PublicAPIError)
          ? "Something went wrong. Please try again."
          : normalizedError.message,
        requestId: request.id
      }
    };

    return reply.status(statusCode).send(payload);
  });
}

function normalizeError(error: unknown): {
  cause: unknown;
  message: string;
  statusCode: number;
} {
  if (error instanceof Error) {
    const statusCode =
      "statusCode" in error && typeof error.statusCode === "number"
        ? error.statusCode
        : 500;
    return { cause: error, message: error.message, statusCode };
  }

  return {
    cause: error,
    message: "The request could not be processed.",
    statusCode: 500
  };
}
