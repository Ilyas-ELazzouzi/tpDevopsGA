const http = require("http");

const baseUrl = process.env.BASE_URL || "http://127.0.0.1:3000";

function request(path) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const req = http.get(url, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString("utf8")
        });
      });
    });
    req.on("error", reject);
    req.setTimeout(5000, () => {
      req.destroy(new Error(`Timeout requesting ${url}`));
    });
  });
}

async function assertHealth() {
  const response = await request("/health");
  if (response.statusCode !== 200) {
    throw new Error(`/health expected 200, got ${response.statusCode}`);
  }

  const payload = JSON.parse(response.body);
  if (payload.status !== "healthy") {
    throw new Error(`/health expected status "healthy", got ${JSON.stringify(payload)}`);
  }

  console.log("OK /health");
}

async function assertMetrics() {
  const response = await request("/metrics");
  if (response.statusCode !== 200) {
    throw new Error(`/metrics expected 200, got ${response.statusCode}`);
  }

  const contentType = response.headers["content-type"] || "";
  if (!contentType.includes("text/plain")) {
    throw new Error(`/metrics unexpected content-type: ${contentType}`);
  }

  if (!response.body.includes("http_requests_total")) {
    throw new Error("/metrics missing http_requests_total metric");
  }

  console.log("OK /metrics");
}

async function main() {
  await assertHealth();
  await assertMetrics();
  console.log("Smoke tests passed");
}

main().catch((error) => {
  console.error("Smoke tests failed:", error.message);
  process.exit(1);
});
