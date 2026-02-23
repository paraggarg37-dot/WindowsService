package org.example;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * A simple HTTP server designed to run as a Windows Service via WinSW.
 * <p>
 * Endpoints:
 *   GET /        → Welcome page (HTML)
 *   GET /health  → JSON health check
 * <p>
 * Default port: 8080 (override with PORT environment variable).
 */
public class Main {

    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public static void main(String[] args) throws IOException {

        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        // ── Root endpoint ───────────────────────────────────────────
        server.createContext("/", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                String html = "<!DOCTYPE html>"
                        + "<html><head><title>Java HTTP Service</title></head>"
                        + "<body style=\"font-family:sans-serif;max-width:600px;margin:40px auto\">"
                        + "<h1>&#9989; Java HTTP Service is running</h1>"
                        + "<p>Server time: " + LocalDateTime.now().format(FMT) + "</p>"
                        + "<p>Try <a href=\"/health\">/health</a> for a JSON health check.</p>"
                        + "</body></html>";
                byte[] bytes = html.getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "text/html; charset=UTF-8");
                exchange.sendResponseHeaders(200, bytes.length);
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(bytes);
                }
            }
        });

        // ── Health endpoint ─────────────────────────────────────────
        server.createContext("/health", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                String json = "{\"status\":\"ok\",\"timestamp\":\""
                        + LocalDateTime.now().format(FMT) + "\"}";
                byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "application/json");
                exchange.sendResponseHeaders(200, bytes.length);
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(bytes);
                }
            }
        });

        // Graceful shutdown hook (WinSW sends SIGTERM on service stop)
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("[" + LocalDateTime.now().format(FMT)
                    + "] Shutting down HTTP server...");
            server.stop(2);  // allow 2 seconds for in-flight requests
        }));

        server.setExecutor(null); // default single-threaded executor
        server.start();

        System.out.println("[" + LocalDateTime.now().format(FMT)
                + "] Java HTTP Service started on port " + port);
    }
}