const express = require("express");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const BACKEND_URL = (process.env.BACKEND_URL || "http://127.0.0.1:5000").replace(/\/$/, "");

app.set("view engine", "ejs");
app.set("views", "./views");
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static("public"));

async function backendRequest(path, options = {}) {
  const response = await fetch(`${BACKEND_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(body.error || "The backend returned an error.");
    error.status = response.status;
    error.fields = body.fields || {};
    throw error;
  }
  return body;
}

app.get("/", (req, res) => res.render("index", { form: {}, error: null }));

app.get("/api/health", async (req, res) => {
  try {
    const backend = await backendRequest("/api/health");
    res.json({ status: "ok", service: "express-frontend", backend });
  } catch (error) {
    res.status(502).json({ status: "error", error: "Backend is unavailable.", details: error.message });
  }
});

app.post("/submit", async (req, res) => {
  const form = { name: req.body.name || "", email: req.body.email || "", message: req.body.message || "" };
  try {
    const result = await backendRequest("/api/submit", {
      method: "POST",
      body: JSON.stringify(form),
    });
    res.render("result", { result });
  } catch (error) {
    res.status(error.status === 400 ? 400 : 502).render("index", {
      form,
      error: error.status === 400 ? error : new Error("Could not contact the Flask backend."),
    });
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Express frontend listening on port ${PORT}`);
  console.log(`Using Flask backend at ${BACKEND_URL}`);
});
