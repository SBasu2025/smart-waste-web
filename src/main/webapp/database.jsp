<%@ page import="java.sql.*, java.util.*" %>
<%@ page import="com.smartwaste.dao.DBUtil" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Smart Waste — Database Viewer</title>

  <style>
    body {
      font-family: Arial, Helvetica, sans-serif;
      background: #f5f0e1;
      margin: 0;
      padding: 0;
    }
    header {
      background: #2b6cb0;
      color: white;
      padding: 18px 28px;
    }
    h1 {
      margin: 0;
      font-size: 26px;
    }
    .container {
      width: 92%;
      max-width: 1200px;
      margin: 22px auto;
      background: #fff;
      padding: 22px;
      border-radius: 8px;
      box-shadow: 0 6px 18px rgba(0,0,0,0.08);
    }
    .controls {
      display: flex;
      gap: 10px;
      align-items: center;
      margin-bottom: 16px;
    }
    input[type="text"] {
      padding: 8px 10px;
      border-radius: 6px;
      border: 1px solid #ddd;
    }
    button {
      padding: 10px 14px;
      border-radius: 6px;
      border: 1px solid #cbd5e1;
      background: #e2e8f0;
      cursor: pointer;
      transition: transform 120ms ease, background 120ms ease;
    }
    button:hover {
      transform: scale(1.02);
      background: #c9d5ea;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 12px;
      margin-bottom: 26px;
      font-size: 14px;
    }
    th, td {
      border: 1px solid #e6e6e6;
      padding: 8px 10px;
      text-align: left;
    }
    th {
      background: #f1f5f9;
      font-weight: 700;
    }
    caption {
      text-align: left;
      margin-bottom: 4px;
      font-size: 16px;
      font-weight: 700;
    }
    .small { font-size: 13px; color:#555; }
    .err { color:maroon; font-weight:700; margin:12px 0; }
  </style>
</head>

<body>
<header>
  <h1>Smart Waste — Database Viewer</h1>
</header>

<div class="container">

<%
    // -----------------------------
    // Validate incoming city_id
    // -----------------------------
    String cityParam = request.getParameter("city_id");
    Long cityId = null;
    try {
        if (cityParam != null && !cityParam.trim().isEmpty()) {
            cityId = Long.parseLong(cityParam.trim());
        }
    } catch (Exception ignored) { cityId = null; }

%>

  <!-- Filter row -->
  <div class="controls">
    <form method="get" style="display:flex; gap:10px; align-items:center;">
      <label class="small">city_id:</label>
      <input type="text" name="city_id"
             value="<%= (cityParam != null ? cityParam : "") %>"
             placeholder="e.g., 1"/>
      <button type="submit">Apply</button>
    </form>

    <button onclick="location.reload()">Refresh</button>
    <button onclick="window.location.href='<%= request.getContextPath() %>/dashboard.jsp'">Back to Dashboard</button>
  </div>

<%
    // -----------------------------
    // Open DB Connection
    // -----------------------------
    try (Connection conn = DBUtil.getConnection()) {
%>

  <!--  TABLE: CITY  -->
  <caption>CITY <span class="small">(<%= cityId != null ? ("filtered by id=" + cityId) : "all" %>)</span></caption>
  <table>
    <thead>
      <tr><th>id</th><th>name</th></tr>
    </thead>
    <tbody>
    <%
      String sqlCity = (cityId != null)
        ? "SELECT id, name FROM city WHERE id = ?"
        : "SELECT id, name FROM city ORDER BY id";

      try (PreparedStatement ps = conn.prepareStatement(sqlCity)) {
        if (cityId != null) ps.setLong(1, cityId);

        try (ResultSet rs = ps.executeQuery()) {
          while (rs.next()) {
    %>
        <tr>
          <td><%= rs.getLong("id") %></td>
          <td><%= rs.getString("name") %></td>
        </tr>
    <%
          }
        }
      }
    %>
    </tbody>
  </table>


  <!--  TABLE: ROUTE  -->
  <caption>ROUTE <span class="small">(<%= cityId != null ? ("city_id=" + cityId) : "all" %>)</span></caption>
  <table>
    <thead>
      <tr><th>id</th><th>city_id</th><th>name</th><th>description</th></tr>
    </thead>
    <tbody>
    <%
      String sqlRoute = (cityId != null)
        ? "SELECT id, city_id, name, description FROM route WHERE city_id=? ORDER BY id"
        : "SELECT id, city_id, name, description FROM route ORDER BY id";

      try (PreparedStatement ps = conn.prepareStatement(sqlRoute)) {
        if (cityId != null) ps.setLong(1, cityId);

        try (ResultSet rs = ps.executeQuery()) {
          while (rs.next()) {
    %>
        <tr>
          <td><%= rs.getLong("id") %></td>
          <td><%= rs.getLong("city_id") %></td>
          <td><%= rs.getString("name") %></td>
          <td><%= rs.getString("description") %></td>
        </tr>
    <%
          }
        }
      }
    %>
    </tbody>
  </table>


  <!--TABLE: BIN -->
  <caption>BIN <span class="small">(<%= cityId != null ? "routes in city_id=" + cityId : "all" %>)</span></caption>
  <table>
    <thead>
      <tr>
        <th>id</th><th>route_id</th><th>name</th><th>latitude</th><th>longitude</th>
        <th>fill_percent</th><th>last_cleared_at</th>
      </tr>
    </thead>
    <tbody>
    <%
      if (cityId != null) {
        String sqlBin =
            "SELECT b.id, b.route_id, b.name, b.latitude, b.longitude, b.fill_percent, b.last_cleared_at " +
            "FROM bin b JOIN route r ON b.route_id = r.id " +
            "WHERE r.city_id=? ORDER BY b.route_id, b.id";

        try (PreparedStatement ps = conn.prepareStatement(sqlBin)) {
          ps.setLong(1, cityId);

          try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
    %>
        <tr>
          <td><%= rs.getLong("id") %></td>
          <td><%= rs.getLong("route_id") %></td>
          <td><%= rs.getString("name") %></td>
          <td><%= rs.getDouble("latitude") %></td>
          <td><%= rs.getDouble("longitude") %></td>
          <td><%= rs.getInt("fill_percent") %></td>
          <td><%= rs.getTimestamp("last_cleared_at") %></td>
        </tr>
    <%
            }
          }
        }
      } else {
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT id, route_id, name, latitude, longitude, fill_percent, last_cleared_at FROM bin ORDER BY route_id,id");
             ResultSet rs = ps.executeQuery()) {
          while (rs.next()) {
    %>
        <tr>
          <td><%= rs.getLong("id") %></td>
          <td><%= rs.getLong("route_id") %></td>
          <td><%= rs.getString("name") %></td>
          <td><%= rs.getDouble("latitude") %></td>
          <td><%= rs.getDouble("longitude") %></td>
          <td><%= rs.getInt("fill_percent") %></td>
          <td><%= rs.getTimestamp("last_cleared_at") %></td>
        </tr>
    <%
          }
        }
      }
    %>
    </tbody>
  </table>


  <!--  TABLE: VEHICLE ACTION  -->
  <caption>VEHICLE_ACTION <span class="small">(<%= cityId != null ? "routes in city_id=" + cityId : "all" %>)</span></caption>
  <table>
    <thead>
      <tr><th>id</th><th>route_id</th><th>vehicle_number</th><th>cleared_at</th></tr>
    </thead>
    <tbody>
<%
    String sqlVA = (cityId != null)
        ? "SELECT va.id, va.route_id, va.vehicle_number, va.cleared_at " +
          "FROM vehicle_action va JOIN route r ON va.route_id = r.id " +
          "WHERE r.city_id=? ORDER BY va.id DESC"
        : "SELECT id, route_id, vehicle_number, cleared_at FROM vehicle_action ORDER BY id DESC";

    try (PreparedStatement ps = conn.prepareStatement(sqlVA)) {
        if (cityId != null) ps.setLong(1, cityId);

        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
%>
        <tr>
          <td><%= rs.getLong("id") %></td>
          <td><%= rs.getLong("route_id") %></td>
          <td><%= rs.getString("vehicle_number") %></td>
          <td><%= rs.getTimestamp("cleared_at") %></td>
        </tr>
<%
            }
        }
    }
%>
    </tbody>
  </table>


  <div class="small">Last refreshed: <%= new java.util.Date() %></div>

<%
    } catch (Exception ex) {
%>
  <div class="err">Database Error: <%= ex.getMessage() %></div>
<%
    }
%>

</div>
</body>
</html>
