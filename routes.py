# ---------- ANALYTICS: STEP 1 – list available algorithms ----------

@bp.get("/api/analytics/algos")
def analytics_algos():
    """
    Returns list of available algorithms from DB.
    Plug your SQL here; this example assumes a column 'algo_name'.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # TODO: replace with your actual query if different
        cur.execute("SELECT DISTINCT algo_name FROM algo_output ORDER BY algo_name")
        algos = [row[0] for row in cur.fetchall()]

        conn.close()
        return jsonify({"status": "ok", "algos": algos})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ---------- ANALYTICS: STEP 2 – get pgroups/pnames/vehicles/psns for an algorithm ----------

@bp.post("/api/analytics/params_for_algo")
def analytics_params_for_algo():
    """
    Given an algorithm name, return distinct pgroups, pnames, vehicles, psns
    for that algorithm only.

    This is where you plug your second SQL query.
    """
    data = request.get_json(silent=True) or {}
    algo_name = data.get("algo_name")
    if not algo_name:
        return jsonify({"status": "error", "message": "algo_name is required"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # TODO: replace this SQL with your existing query if it's more complex,
        # but it should return at least pgroup, pname, vehicle, psn.
        cur.execute(
            """
            SELECT DISTINCT pgroup, pname, vehicle, psn
            FROM algo_output
            WHERE algo_name = ?
            """,
            (algo_name,)
        )
        rows = cur.fetchall()
        conn.close()

        pgroups  = sorted({row[0] for row in rows if row[0] is not None})
        pnames   = sorted({row[1] for row in rows if row[1] is not None})
        vehicles = sorted({row[2] for row in rows if row[2] is not None})
        psns     = sorted({row[3] for row in rows if row[3] is not None})

        return jsonify({
            "status": "ok",
            "algo_name": algo_name,
            "pgroups": pgroups,
            "pnames": pnames,
            "vehicles": vehicles,
            "psns": psns,
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ---------- ANALYTICS: STEP 3 – fetch data for selected algo/vehicle/psn/pname and plot ----------

@bp.post("/api/analytics/data")
def analytics_data():
    """
    Given algo_name, vehicle, psn, pname, return data to plot.
    Plug your existing SQL query logic here – this example assumes:
      columns: date, pvalue, pgroup, pname, vehicle, psn
    """
    data = request.get_json(silent=True) or {}
    algo_name = data.get("algo_name")
    vehicle   = data.get("vehicle")
    psn       = data.get("psn")
    pname     = data.get("pname")

    missing = [k for k, v in [
        ("algo_name", algo_name),
        ("vehicle",   vehicle),
        ("psn",       psn),
        ("pname",     pname),
    ] if not v]

    if missing:
        return jsonify({
            "status": "error",
            "message": "Missing required parameters: " + ", ".join(missing),
        }), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # TODO: replace with your existing "main" analytics SQL
        cur.execute(
            """
            SELECT date, pvalue, pgroup, pname, vehicle, psn
            FROM algo_output
            WHERE algo_name = ?
              AND vehicle   = ?
              AND psn       = ?
              AND pname     = ?
            ORDER BY date
            """,
            (algo_name, vehicle, psn, pname)
        )
        rows = cur.fetchall()
        conn.close()

        points = [
            {
                "date":    row[0],
                "pvalue":  row[1],
                "pgroup":  row[2],
                "pname":   row[3],
                "vehicle": row[4],
                "psn":     row[5],
            }
            for row in rows
        ]

        return jsonify({
            "status": "ok",
            "algo_name": algo_name,
            "vehicle":   vehicle,
            "psn":       psn,
            "pname":     pname,
            "points":    points,
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
