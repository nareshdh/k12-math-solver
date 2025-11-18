  // ---- Analytics: meta + drag & drop + Plotly ----
  const algoListEl     = document.getElementById("analytics-algo-list");
  const pgroupListEl   = document.getElementById("analytics-pgroup-list");
  const pnameListEl    = document.getElementById("analytics-pname-list");
  const vehicleListEl  = document.getElementById("analytics-vehicle-list");
  const psnListEl      = document.getElementById("analytics-psn-list");

  const inputAlgo      = document.getElementById("analytics-input-algo");
  const inputVehicle   = document.getElementById("analytics-input-vehicle");
  const inputPsn       = document.getElementById("analytics-input-psn");
  const inputPname     = document.getElementById("analytics-input-pname");

  const analyticsSubmitBtn = document.getElementById("analytics-submit-btn");
  const analyticsStatusEl  = document.getElementById("analytics-status");
  const analyticsPlotDiv   = document.getElementById("analytics-plot");

  // ---- drag & drop helpers ----
  function makeDropTarget(input) {
    if (!input) return;
    input.addEventListener("dragover", (e) => {
      e.preventDefault();
    });
    input.addEventListener("drop", (e) => {
      e.preventDefault();
      const value = e.dataTransfer.getData("text/plain");
      if (value) {
        input.value = value;
      }
    });
  }

  makeDropTarget(inputAlgo);
  makeDropTarget(inputVehicle);
  makeDropTarget(inputPsn);
  makeDropTarget(inputPname);

  function makeToken(value, kind) {
    const span = document.createElement("span");
    span.className = "analytics-token";
    span.textContent = value;
    span.setAttribute("draggable", "true");

    span.addEventListener("dragstart", (e) => {
      e.dataTransfer.setData("text/plain", value);
    });

    span.addEventListener("click", () => {
      // If it's an algorithm token, treat click as "select algo"
      if (kind === "algo") {
        if (inputAlgo) inputAlgo.value = value;
        onAlgoSelected(value);
        return;
      }

      // For other kinds, fill the most relevant input
      if (kind === "pname" && inputPname) { inputPname.value = value; return; }
      if (kind === "vehicle" && inputVehicle) { inputVehicle.value = value; return; }
      if (kind === "psn" && inputPsn) { inputPsn.value = value; return; }
      if (kind === "pgroup") {
        // no direct input for pgroup right now; ignore or extend later
        return;
      }

      // fallback: fill first empty
      const inputs = [inputAlgo, inputVehicle, inputPsn, inputPname];
      for (const inp of inputs) {
        if (inp && !inp.value) { inp.value = value; break; }
      }
    });

    return span;
  }

  function fillContainer(container, arr, kind) {
    container.textContent = "";
    if (!arr || !arr.length) {
      container.textContent = "(no values)";
      return;
    }
    arr.forEach(v => {
      const tok = makeToken(v, kind);
      container.appendChild(tok);
    });
  }

  // ---- Load global meta (for initial view) ----
  async function loadAnalyticsMeta() {
    if (!algoListEl || !pgroupListEl || !pnameListEl || !vehicleListEl || !psnListEl) return;
    try {
      const res = await fetch("/api/analytics/meta");
      const data = await res.json();
      if (data.status !== "ok") {
        algoListEl.textContent = "Error: " + (data.message || "Failed to load");
        return;
      }

      const { algos, pgroups, pnames, vehicles, psns } = data;

      fillContainer(algoListEl, algos, "algo");
      fillContainer(pgroupListEl, pgroups, "pgroup");
      fillContainer(pnameListEl, pnames, "pname");
      fillContainer(vehicleListEl, vehicles, "vehicle");
      fillContainer(psnListEl, psns, "psn");

    } catch (e) {
      algoListEl.textContent = "Network error loading analytics meta: " + e;
    }
  }

  // ---- When an algorithm is chosen, auto-populate other fields ----
  async function onAlgoSelected(algoName) {
    if (!algoName) return;
    analyticsStatusEl.textContent = " Loading parameters for " + algoName + " ...";

    try {
      const res = await fetch("/api/analytics/meta_for_algo?algo_name=" + encodeURIComponent(algoName));
      const data = await res.json();
      if (data.status !== "ok") {
        analyticsStatusEl.textContent = data.message || "Error loading algo parameters";
        return;
      }

      const { pgroups, pnames, vehicles, psns } = data;

      // Update the top row lists to show only values for this algorithm
      fillContainer(pgroupListEl, pgroups, "pgroup");
      fillContainer(pnameListEl, pnames, "pname");
      fillContainer(vehicleListEl, vehicles, "vehicle");
      fillContainer(psnListEl, psns, "psn");

      // Auto-fill the input boxes with the first available values (if any)
      if (inputAlgo)    inputAlgo.value    = algoName;
      if (inputVehicle) inputVehicle.value = vehicles && vehicles.length ? vehicles[0] : "";
      if (inputPsn)     inputPsn.value     = psns && psns.length ? psns[0] : "";
      if (inputPname)   inputPname.value   = pnames && pnames.length ? pnames[0] : "";

      analyticsStatusEl.textContent = " Parameters loaded for " + algoName + ". Adjust if needed and click Submit.";
    } catch (e) {
      analyticsStatusEl.textContent = " Network error loading algo parameters: " + e;
    }
  }

  // If user types algo manually and leaves the field, also load its parameters
  inputAlgo?.addEventListener("change", () => {
    const v = inputAlgo.value.trim();
    if (v) {
      onAlgoSelected(v);
    }
  });
  inputAlgo?.addEventListener("blur", () => {
    const v = inputAlgo.value.trim();
    if (v) {
      onAlgoSelected(v);
    }
  });

  // ---- Submit: fetch data & plot ----
  analyticsSubmitBtn?.addEventListener("click", async function() {
    if (!analyticsPlotDiv || !analyticsStatusEl) return;

    const algo_name = inputAlgo?.value.trim();
    const vehicle   = inputVehicle?.value.trim();
    const psn       = inputPsn?.value.trim();
    const pname     = inputPname?.value.trim();

    if (!algo_name || !vehicle || !psn || !pname) {
      analyticsStatusEl.textContent = " Please fill algo_name, vehicle, psn, and pname.";
      return;
    }

    analyticsStatusEl.textContent = " Loading data...";
    try {
      const res = await fetch("/api/analytics/data", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({ algo_name, vehicle, psn, pname })
      });
      const data = await res.json();
      if (data.status !== "ok") {
        analyticsStatusEl.textContent = data.message || "Error loading data";
        return;
      }

      const points = data.points || data.series?.points || data.points || data.points; // keep flexible
      const pts = data.points || data.points || data.points || data.points; // for safety
      const seriesPoints = data.points || data.series?.points || data.points || [];

      const xVals = seriesPoints.map(p => p.date);
      const yVals = seriesPoints.map(p => p.pvalue);

      const trace = {
        x: xVals,
        y: yVals,
        mode: "markers+lines",
        type: "scatter",
        name: `${pname} (${algo_name}, ${vehicle}, ${psn})`
      };

      const layout = {
        margin: { t: 20, r: 10, b: 50, l: 60 },
        xaxis: { title: "date" },
        yaxis: { title: "pvalue" }
      };

      Plotly.newPlot(analyticsPlotDiv, [trace], layout);
      analyticsStatusEl.textContent = ` Loaded ${seriesPoints.length} points.`;

    } catch (e) {
      analyticsStatusEl.textContent = " Network error: " + e;
    }
  });

  // Load global metadata on page load (initial lists)
  loadAnalyticsMeta();
