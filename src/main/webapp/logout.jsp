<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.*, java.text.SimpleDateFormat" %>
<%
    // 获取当前用户
    String username = (String) session.getAttribute("username");

    if (username != null) {
        // 从在线用户列表中移除
        Map<String, Long> onlineUsers = (Map<String, Long>) application.getAttribute("onlineUsers");
        if (onlineUsers != null) {
            onlineUsers.remove(username);
        }

        // 添加系统消息
        List<Map<String, String>> messages = (List<Map<String, String>>) application.getAttribute("messages");
        if (messages != null) {
            Map<String, String> systemMsg = new HashMap<>();
            systemMsg.put("id", String.valueOf(System.currentTimeMillis()));
            systemMsg.put("sender", "系统");
            systemMsg.put("content", username + " 离开了聊天室");
            systemMsg.put("type", "system");
            systemMsg.put("time", new SimpleDateFormat("HH:mm:ss").format(new Date()));

            synchronized(messages) {
                if (messages.size() >= 100) {
                    messages.remove(0);
                }
                messages.add(systemMsg);
            }
        }

        // 清除session
        session.invalidate();
    }

    // 延迟重定向，确保消息已经添加
    response.setHeader("Refresh", "1;url=index.jsp");
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>退出聊天室</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: white;
            text-align: center;
        }

        .logout-container {
            max-width: 400px;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }

        .logout-icon {
            font-size: 4rem;
            margin-bottom: 20px;
            color: #ff6b6b;
        }

        h1 {
            font-size: 2rem;
            margin-bottom: 10px;
        }

        p {
            opacity: 0.9;
            margin-bottom: 30px;
        }

        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
<div class="logout-container">
    <div class="logout-icon">
        <i class="fas fa-sign-out-alt"></i>
    </div>
    <h1>正在退出聊天室...</h1>
    <p><%= username != null ? "再见，" + username + "！" : "已成功退出" %></p>
    <div>
        <div class="loading"></div>
        <div style="margin-top: 10px; font-size: 0.9rem;">
            正在重定向到登录页面...
        </div>
    </div>
</div>
</body>
</html>