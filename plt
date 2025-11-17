  // ---- Analytics: meta + drag & drop + Plotly ----
  const algoListEl     = document.getElementById("analytics-algo-list");
  const pgroupListEl   = document.getElementById("analytics-pgroup-list");
  const pnameListEl    = document.getElementById("analytics-pname-list");
  const vehicleListEl  = document.getElementById("analytics-vehicle-list");
  const psnListEl      = document.getElementById("analytics-psn-list");

  const inputAlgo   = document.getElementById("analytics-input-algo");
  const inputVehicle= document.getElementById("analytics-input-vehicle");
  const inputPsn    = document.getElementById("analytics-input-psn");
  const inputPname  = document.getElementById("analytics-input-pname");

  const analyticsSubmitBtn = document.getElementById("analytics-submit-btn");
  const analyticsStatusEl  = document.getElementById("analytics-status");
  const analyticsPlotDiv   = document.getElementById("analytics-plot");

  function makeToken(value) {
    const span = document.createElement("span");
    span.className = "analytics-token";
    span.textContent = value;
    span.setAttribute("draggable", "true");

    span.addEventListener("dragstart", (e) => {
      e.dataTransfer.setData("text/plain", value);
    });

    // Also support click-to-fill: click will try to fill the "most relevant" box
    span.addEventListener("click", () => {
      // default: fill algo if that input is empty, otherwise pname, etc.
      if (algoListEl.contains(span) && inputAlgo) { inputAlgo.value = value; return; }
      if (pnameListEl.contains(span) && inputPname) { inputPname.value = value; return; }
      if (vehicleListEl.contains(span) && inputVehicle) { inputVehicle.value = value; return; }
      if (psnListEl.contains(span) && inputPsn) { inputPsn.value = value; return; }
      // fallback: fill first empty input
      const inputs = [inputAlgo, inputVehicle, inputPsn, inputPname];
      for (const inp of inputs) {
        if (inp && !inp.value) { inp.value = value; break; }
      }
    });

    return span;
  }

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

  // Attach drop behavior to all four inputs
  makeDropTarget(inputAlgo);
  makeDropTarget(inputVehicle);
  makeDropTarget(inputPsn);
  makeDropTarget(inputPname);

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

      function fillContainer(container, arr) {
        container.textContent = "";
        if (!arr || !arr.length) {
          container.textContent = "(no values)";
          return;
        }
        arr.forEach(v => {
          const tok = makeToken(v);
          container.appendChild(tok);
        });
      }

      fillContainer(algoListEl, algos);
      fillContainer(pgroupListEl, pgroups);
      fillContainer(pnameListEl, pnames);
      fillContainer(vehicleListEl, vehicles);
      fillContainer(psnListEl, psns);

    } catch (e) {
      algoListEl.textContent = "Network error loading analytics meta: " + e;
    }
  }

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

      const points = data.points || [];
      const dates  = points.map(p => p.date);
      const values = points.map(p => p.pvalue);

      const trace = {
        x: dates,
        y: values,
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
      analyticsStatusEl.textContent = ` Loaded ${points.length} points.`;

    } catch (e) {
      analyticsStatusEl.textContent = " Network error: " + e;
    }
  });

  // Load meta on page load (if Analytics tab exists)
  loadAnalyticsMeta();
