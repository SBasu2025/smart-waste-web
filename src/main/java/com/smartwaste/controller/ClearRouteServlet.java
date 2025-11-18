package com.smartwaste.controller;

import com.smartwaste.dao.DBUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet("/clearRoute")
public class ClearRouteServlet extends HttpServlet {

    private static final String UPDATE_BIN_SQL =
            "UPDATE bin SET fill_percent = 0, last_cleared_at = NOW() WHERE route_id = ?";
    private static final String INSERT_ACTION_SQL =
            "INSERT INTO vehicle_action (route_id, vehicle_number) VALUES (?, ?)";

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");

        String[] routeIds = req.getParameterValues("route_id");
        String vehiclesParam = req.getParameter("vehicles");
        int vehicles = 1;
        try {
            if (vehiclesParam != null && !vehiclesParam.trim().isEmpty()) {
                vehicles = Integer.parseInt(vehiclesParam.trim());
                if (vehicles < 1) vehicles = 1;
            }
        } catch (NumberFormatException nfe) {
            vehicles = 1;
        }

        
        String vehicleNumber = req.getParameter("vehicle_number");
        if (vehicleNumber == null || vehicleNumber.trim().isEmpty()) {
            vehicleNumber = "AUTO";
        }

        if (routeIds == null || routeIds.length == 0) {
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp?err=" + encode("No routes selected"));
            return;
        }

        if (routeIds.length > vehicles) {
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp?err=" + encode("You selected more routes than vehicles (" + vehicles + ")."));
            return;
        }

        try (Connection conn = DBUtil.getConnection()) {
            boolean originalAutoCommit = conn.getAutoCommit();
            conn.setAutoCommit(false);
            try (PreparedStatement psUpdate = conn.prepareStatement(UPDATE_BIN_SQL);
                 PreparedStatement psInsert = conn.prepareStatement(INSERT_ACTION_SQL)) {

                for (String ridStr : routeIds) {
                    int rid = Integer.parseInt(ridStr);
                    psUpdate.setInt(1, rid);
                    psUpdate.executeUpdate();

                    psInsert.setInt(1, rid);
                    psInsert.setString(2, vehicleNumber);
                    psInsert.executeUpdate();
                }

                conn.commit();
                resp.sendRedirect(req.getContextPath() + "/dashboard.jsp?msg=" + encode("Selected routes cleared successfully!"));
            } catch (Exception e) {
                try { conn.rollback(); } catch (Exception ignore) {}
                e.printStackTrace();
                resp.sendRedirect(req.getContextPath() + "/dashboard.jsp?err=" + encode("Error while clearing routes: " + e.getMessage()));
            } finally {
                try { conn.setAutoCommit(originalAutoCommit); } catch (Exception ignore) {}
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp?err=" + encode("Database connection error: " + ex.getMessage()));
        }
    }

    private String encode(String s) {
        try {
            return java.net.URLEncoder.encode(s, "UTF-8");
        } catch (Exception ex) {
            return s;
        }
    }
}
