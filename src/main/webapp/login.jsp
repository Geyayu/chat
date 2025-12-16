<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*" %>
<%
    // 获取用户名
    String username = request.getParameter("username");

    if (username != null && !username.trim().isEmpty()) {
        username = username.trim();

        // 存储用户信息到session
        session.setAttribute("username", username);
        session.setAttribute("loginTime", new Date());
        session.setAttribute("userAgent", request.getHeader("User-Agent"));
        session.setAttribute("ipAddress", request.getRemoteAddr());

        // 添加用户到在线列表
        @SuppressWarnings("unchecked")
        Map<String, Map<String, Object>> onlineUsers =
                (Map<String, Map<String, Object>>) application.getAttribute("onlineUsers");

        if (onlineUsers == null) {
            onlineUsers = new HashMap<String, Map<String, Object>>();
            application.setAttribute("onlineUsers", onlineUsers);
        }

        // 检查用户名是否已存在
        boolean usernameExists = onlineUsers.containsKey(username);
        if (usernameExists) {
            // 用户名已存在，添加随机后缀
            username = username + "_" + (int)(Math.random() * 1000);
            session.setAttribute("username", username);
        }

        Map<String, Object> userInfo = new HashMap<>();
        userInfo.put("loginTime", new Date());
        userInfo.put("ipAddress", request.getRemoteAddr());
        userInfo.put("userAgent", request.getHeader("User-Agent"));
        userInfo.put("lastActive", new Date());

        onlineUsers.put(username, userInfo);

        // 添加欢迎消息到聊天记录
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> messages =
                (List<Map<String, Object>>) application.getAttribute("messages");

        if (messages == null) {
            messages = new ArrayList<Map<String, Object>>();
            application.setAttribute("messages", messages);
        }

        Map<String, Object> welcomeMsg = new HashMap<>();
        welcomeMsg.put("type", "system");
        welcomeMsg.put("sender", "系统");
        welcomeMsg.put("content", username + " 进入了聊天室");
        welcomeMsg.put("timestamp", new Date());
        welcomeMsg.put("color", "green");

        // 限制消息数量（最多500条）
        if (messages.size() >= 500) {
            messages.remove(0);
        }
        messages.add(welcomeMsg);

        // 重定向到聊天页面
        response.sendRedirect("chat.jsp");
        return;
    } else {
        // 用户名无效，返回首页
        response.sendRedirect("index.jsp");
        return;
    }
%>