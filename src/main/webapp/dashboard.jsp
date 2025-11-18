<%@ page import="java.sql.*, java.util.*" %>
<%@ page import="com.smartwaste.dao.DBUtil" %>
<%@ page session="true" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Smart Waste Dashboard</title>
    <style>
        
        body {
            font-family: Arial, Helvetica, sans-serif;
            background: #f5f0e1; /* light beige */
            margin: 0;
            padding: 0;
        }
        header {
            background: #2b6cb0;
            color: white;
            padding: 24px 32px;
        }
        h1 { margin: 0; font-size: 36px; }
        .container {
            width: 85%;
            max-width: 1100px;
            margin: 28px auto;
            background: #fff;
            padding: 28px;
            border-radius: 10px;
            box-shadow: 0 6px 18px rgba(0,0,0,0.08);
        }

        
        label { font-weight: 600; margin-right: 8px; display:inline-block; }
        select, button, input[type="text"], input[type="number"] {
            padding: 10px 12px;
            margin: 6px 0;
            font-size: 15px;
            border: 1px solid #ddd;
            border-radius: 6px;
            background: #fff;
            outline: none;
        }
        button {
            background: #e2e8f0;
            border: 1px solid #cbd5e1;
            cursor: pointer;
            transition: transform 120ms ease, background 120ms ease, box-shadow 120ms ease;
            border-radius: 6px;
            padding: 12px 18px;
            font-size: 16px;
        }
        button:hover {
            background: #c9d5ea; 
            transform: scale(1.02);
            box-shadow: 0 4px 14px rgba(0,0,0,0.08);
        }

        /* Table/list */
        .routes-list { margin-top: 18px; }
        .route-item { margin-bottom: 14px; padding: 10px 12px; border-radius: 8px; background: #fbfbfb; border: 1px solid #f0f0f0; }
        .route-title { font-size: 18px; font-weight: 700; margin-bottom: 6px; display:flex; align-items:center; gap:10px; }
        .bins-list { margin: 6px 0 0 20px; padding: 0; list-style: disc; color: #333; }
        .bins-list li { margin: 4px 0; font-size: 14px; }

        .meta { margin-top: 16px; color: #2d3748; font-weight: 600; }
        .msg { color: green; font-weight: 700; margin: 12px 0; }
        .err { color: maroon; font-weight: 700; margin: 12px 0; }

        
        .footer-actions { margin-top: 28px; display:flex; gap:12px; align-items:center; }
        #showDbBtn { background: #f7c0b8; border: 1px solid #f0a99a; }
        #showDbBtn:hover { background: #f2a794; }

        
        @media (max-width: 700px) {
            .container { width: 94%; padding: 16px; }
            h1 { font-size: 26px; }
        }
    </style>
</head>
<body>
<header>
    <h1>Smart Waste Management Dashboard</h1>
</header>

<div class="container">

<%
    // Session state for cleared routes (kept for compatibility but DB driven visibility used)
    @SuppressWarnings("unchecked")
    List<Long> clearedRoutes = (List<Long>) session.getAttribute("clearedRoutes");
    if (clearedRoutes == null) {
        clearedRoutes = new ArrayList<>();
        session.setAttribute("clearedRoutes", clearedRoutes);
    }

    // Messages possibly set by servlet redirects
    String msg = request.getParameter("msg");
    String err = request.getParameter("err");
    if (msg != null && !msg.isEmpty()) {
%>
        <div class="msg"><%= msg %></div>
<%
    }
    if (err != null && !err.isEmpty()) {
%>
        <div class="err"><%= err %></div>
<%
    }

    String cityIdParam = request.getParameter("city_id");
    String step = request.getParameter("step");
%>


<form method="get" style="margin-bottom: 12px;">
    <label for="city">Select City:</label>
    <select name="city_id" id="city" onchange="this.form.submit()">
        <option value="">-- Choose City --</option>
        <%
            // Populate cities
            try (Connection c = DBUtil.getConnection();
                 Statement s = c.createStatement();
                 ResultSet rs = s.executeQuery("SELECT id, name FROM city ORDER BY name")) {
                while (rs.next()) {
                    long id = rs.getLong("id");
                    String name = rs.getString("name");
                    String sel = (cityIdParam != null && cityIdParam.equals(String.valueOf(id))) ? "selected" : "";
        %>
                    <option value="<%= id %>" <%= sel %>><%= name %></option>
        <%
                }
            } catch (Exception e) {
                out.println("<option value=''>Error loading cities</option>");
            }
        %>
    </select>
</form>

<%
    if (cityIdParam != null && !cityIdParam.isEmpty()) {
        // Ask for number of vehicles (step control)
        if (step == null) {
%>
            <form method="get" style="margin-top: 12px;">
                <input type="hidden" name="city_id" value="<%= cityIdParam %>">
                <input type="hidden" name="step" value="chooseRoutes">
                <label>Enter number of vehicles:</label>
                <input type="number" name="vehicles" min="1" required>
                <button type="submit">Next</button>
            </form>
<%
        } else if ("chooseRoutes".equals(step)) {
            // get vehicles param
            String vehiclesParam = request.getParameter("vehicles");
            int vehicles = 1;
            try {
                if (vehiclesParam != null && !vehiclesParam.trim().isEmpty()) {
                    vehicles = Integer.parseInt(vehiclesParam.trim());
                    if (vehicles < 1) vehicles = 1;
                }
            } catch (NumberFormatException nfe) {
                vehicles = 1;
            }

            // Fetch routes for this city, then fetch all bins for these routes in one batched query
            List<Long> routeIds = new ArrayList<>();
            Map<Long, String> routeNames = new LinkedHashMap<>(); // preserve insertion order
            Map<Long, List<Map<String,Object>>> binsByRoute = new HashMap<>();

            try (Connection conn = DBUtil.getConnection()) {
                // 1) fetch routes — DB-driven: only routes that have at least one bin with fill_percent > 0
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT r.id, r.name, r.description FROM route r " +
                        "WHERE r.city_id = ? AND EXISTS (SELECT 1 FROM bin b WHERE b.route_id = r.id AND b.fill_percent > 0) " +
                        "ORDER BY r.id")) {
                    ps.setLong(1, Long.parseLong(cityIdParam));
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            long rid = rs.getLong("id");
                            routeIds.add(rid);
                            String name = rs.getString("name");
                            String desc = rs.getString("description");
                            routeNames.put(rid, (desc != null && desc.trim().length() > 0) ? (name + " — " + desc) : name);
                        }
                    }
                }

                // 2) fetch bins in a single query if routeIds not empty
                if (!routeIds.isEmpty()) {
                    // build placeholders
                    StringBuilder sb = new StringBuilder();
                    sb.append("SELECT route_id, name, latitude, longitude, fill_percent FROM bin WHERE route_id IN (");
                    for (int i = 0; i < routeIds.size(); ++i) {
                        sb.append("?");
                        if (i < routeIds.size() - 1) sb.append(",");
                    }
                    sb.append(") ORDER BY route_id, id");

                    try (PreparedStatement psb = conn.prepareStatement(sb.toString())) {
                        int idx = 1;
                        for (Long rid : routeIds) {
                            psb.setLong(idx++, rid);
                        }
                        try (ResultSet rsb = psb.executeQuery()) {
                            while (rsb.next()) {
                                long rid = rsb.getLong("route_id");
                                String bname = rsb.getString("name");
                                double lat = rsb.getDouble("latitude");
                                double lon = rsb.getDouble("longitude");
                                int fill = rsb.getInt("fill_percent");

                                List<Map<String,Object>> list = binsByRoute.computeIfAbsent(rid, k -> new ArrayList<>());
                                Map<String,Object> row = new HashMap<>();
                                row.put("name", bname);
                                row.put("lat", lat);
                                row.put("lon", lon);
                                row.put("fill", fill);
                                list.add(row);
                            }
                        }
                    }
                }

            } catch (Exception e) {
                out.println("<p class='err'>Database error while loading routes/bins: " + e.getMessage() + "</p>");
            }

            // If no available routes (all cleared) show message
            if (routeIds.isEmpty()) {
                out.println("<p class='msg'>✅ All routes cleared for this city! Please select another city.</p>");
            } else {
%>
                
                <form method="post" action="<%= request.getContextPath() %>/clearRoute" id="clearForm">
                    <input type="hidden" name="city_id" value="<%= cityIdParam %>">
                    <input type="hidden" name="vehicles" id="vehiclesHidden" value="<%= vehicles %>">
                    <p style="font-weight:700; margin-top:8px;">Available routes in this city:</p>

                    <div class="routes-list" id="routesList">
                        <%
                            for (Long rid : routeIds) {
                        %>
                            <div class="route-item">
                                <div class="route-title">
                                    <label style="margin:0;">
                                        <input type="checkbox" class="routeCheckbox" name="route_id" value="<%= rid %>">
                                    </label>
                                    <div><%= routeNames.get(rid) %></div>
                                </div>

                                <div>
                                    <small style="font-weight:600;">Bins:</small>
                                    <%
                                        List<Map<String,Object>> bins = binsByRoute.get(rid);
                                        if (bins == null || bins.isEmpty()) {
                                            out.print("<div style='margin-left:18px; color:#666;'>No bins on this route</div>");
                                        } else {
                                            out.print("<ul class='bins-list'>");
                                            for (Map<String,Object> b : bins) {
                                                String bname = (String) b.get("name");
                                                double lat = (Double) b.get("lat");
                                                double lon = (Double) b.get("lon");
                                                int fill = (Integer) b.get("fill");
                                                out.print("<li>" + bname + " — " + fill + "% &nbsp;(" + lat + ", " + lon + ")</li>");
                                            }
                                            out.print("</ul>");
                                        }
                                    %>
                                </div>
                            </div>
                        <%
                            } // end for routes
                        %>
                    </div>

                    <div style="margin-top:16px;">
                        <div id="selectionInfo" style="font-weight:600;">You can select up to <span id="vehiclesCount"><%= vehicles %></span> routes.</div>
                    </div>

                    <div class="footer-actions">
                        <button type="submit" id="clearBtn">Clear Selected Routes</button>
                        <div class="meta">(Vehicles available: <span id="metaVehicles"><%= vehicles %></span>)</div>
                        <!--Adding the SHOW DATABASE button-->
                        <button type="button" id="showDbBtn">Show database</button>
                    </div>
                </form>

                <script>
                    
                    (function(){
                        var vehicles = parseInt(document.getElementById('vehiclesHidden').value || '1', 10);
                        var checkboxes = Array.from(document.querySelectorAll('.routeCheckbox'));
                        var info = document.getElementById('selectionInfo');
                        var vehiclesCountSpan = document.getElementById('vehiclesCount');
                        vehiclesCountSpan.textContent = vehicles;

                        function updateState() {
                            var selected = checkboxes.filter(cb => cb.checked).length;
                            // disable unchecked boxes if selected == vehicles
                            checkboxes.forEach(function(cb) {
                                if (!cb.checked) {
                                    cb.disabled = (selected >= vehicles);
                                } else {
                                    cb.disabled = false;
                                }
                            });
                            
                            var rem = vehicles - selected;
                            info.textContent = rem > 0 ? ('You can select ' + rem + ' more route(s).') : 'Selection limit reached.';
                        }

                        
                        checkboxes.forEach(function(cb){
                            cb.addEventListener('change', function(){
                                updateState();
                            });
                        });

                        
                        updateState();

                        
                        document.getElementById('clearForm').addEventListener('submit', function(e){
                            var selected = checkboxes.filter(cb => cb.checked).length;
                            if (selected === 0) {
                                e.preventDefault();
                                alert('Please select at least one route to clear.');
                                return false;
                            }
                            if (selected > vehicles) {
                                e.preventDefault();
                                alert('You selected more routes than vehicles. Please reduce selection.');
                                return false;
                            }
                           
                        });
                    })();
                </script>
<%
            } // end routeIds non-empty
        } else if ("postClear".equals(step)) {
            // deprecated if servlet used; kept for completeness
            String message = (String) request.getAttribute("message");
            if (message == null) message = "Operation completed.";
            out.println("<p class='msg'>" + message + "</p>");
%>
            <form method="get">
                <input type="hidden" name="city_id" value="<%= cityIdParam %>">
                <input type="hidden" name="step" value="chooseRoutes">
                <button type="submit">Continue with same city</button>
            </form>
            <form method="get">
                <button type="submit">Choose another city</button>
            </form>
<%
        } // end chooseRoutes branch
    } else {
        out.println("<p>Please select a city to begin.</p>");
    } // end city selected
%>

</div>

<script>
    
    (function() {
        var btn = document.getElementById('showDbBtn');
        if (!btn) return;
        btn.addEventListener('click', function () {
            var cityId = '<%= cityIdParam != null ? cityIdParam : "" %>';
            var url = '<%= request.getContextPath() %>/database.jsp' + (cityId ? ('?city_id=' + encodeURIComponent(cityId)) : '');
            window.location.href = url;
        });
    })();
</script>
</body>
</html>
