package com.smartwaste.dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.io.InputStream;
public class DBUtil {
private static String url;
private static String username;
private static String password;
private static String driver;
static {
         try (InputStream is = DBUtil.class.getClassLoader().getResourceAsStream("db.properties")) {
            if (is == null) {
                throw new RuntimeException("db.properties not found on classpath (expected in src/main/resources)");
            }
            Properties p = new Properties();
            p.load(is);
            url = p.getProperty("jdbc.url");
            username = p.getProperty("jdbc.username"); 
            password = p.getProperty("jdbc.password");
            driver = p.getProperty("jdbc.driver", "com.mysql.cj.jdbc.Driver");
            Class.forName(driver);
        } catch (Exception e) {
            e.printStackTrace();
            throw new ExceptionInInitializerError("Failed to load DB properties: " + e.getMessage());
        }
    }
    public static Connection getConnection() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }
}
