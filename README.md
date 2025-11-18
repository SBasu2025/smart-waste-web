# smart-waste-web
A fullstack webapp micro-project by Soumyadeep Basu
The **Smart Waste Management Dashboard** is a Java-based web application that helps municipalities track garbage bin fill levels across city routes and optimize vehicle deployment for timely waste collection.  

It provides:
- A dashboard to view cities, routes, bins, and fill percentages  
- A route-clearing workflow with vehicle constraints  
- A database viewer for administrators  
- Real-time updates using MySQL + JDBC  
- Servlet-based business logic and JSP-based UI  

This project follows a **classic Java EE architecture** using Servlets, JSP, JDBC, MySQL, Maven, and Tomcat.

---

## 🛠️ Tech Stack

### **Frontend**
- HTML5  
- CSS3  
- JavaScript  
- JSP (Java Server Pages)

### **Backend**
- Java  
- Servlets (`ClearRouteServlet`)  
- JDBC (PreparedStatements, Transactions)

### **Database**
- MySQL 8.x  
- Automated schema setup via `schema.sql`  

### **Build & Deployment**
- Maven (WAR packaging + dependency management)  
- Apache Tomcat 10/11 (Jakarta EE compatible)  
