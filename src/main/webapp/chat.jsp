<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="java.util.*, java.text.SimpleDateFormat, com.google.gson.Gson" %>
<%
    // ==================== 设置字符编码 ====================
    request.setCharacterEncoding("UTF-8");
    response.setCharacterEncoding("UTF-8");

    // ==================== 处理API请求 ====================
    String action = request.getParameter("action");

    // 1. 处理统计数据请求
    if ("stats".equals(action)) {
        response.setContentType("application/json");
        Map<String, Object> stats = new HashMap<>();

        // 在线用户数
        Object onlineUsersObj = application.getAttribute("onlineUsers");
        int onlineCount = 0;

        if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;
            onlineCount = onlineUsers.size();
        }

        // 消息总数
        List<Map<String, Object>> messages = (List<Map<String, Object>>) application.getAttribute("messages");
        stats.put("online", onlineCount);
        stats.put("messages", messages != null ? messages.size() : 0);

        response.getWriter().write(new Gson().toJson(stats));
        return;
    }

    // 2. 处理发送消息请求
    if ("send".equals(action)) {
        response.setContentType("application/json");

        String username = (String) session.getAttribute("username");
        String message = request.getParameter("message");

        Map<String, Object> result = new HashMap<>();

        // 验证参数
        if (username == null || username.trim().isEmpty()) {
            result.put("success", false);
            result.put("error", "用户未登录");
            response.getWriter().write(new Gson().toJson(result));
            return;
        }

        if (message == null || message.trim().isEmpty()) {
            result.put("success", false);
            result.put("error", "消息内容不能为空");
            response.getWriter().write(new Gson().toJson(result));
            return;
        }

        message = message.trim();

        // 获取消息列表
        List<Map<String, Object>> messages = (List<Map<String, Object>>) application.getAttribute("messages");
        if (messages == null) {
            messages = Collections.synchronizedList(new ArrayList<>());
            application.setAttribute("messages", messages);
        }

        // 检查是否是私聊消息
        boolean isPrivate = message.startsWith("@");
        String recipient = null;
        String actualMessage = message;

        if (isPrivate) {
            // 解析私聊消息格式：@用户名 消息内容
            int spaceIndex = message.indexOf(" ");
            if (spaceIndex > 1) {
                recipient = message.substring(1, spaceIndex);
                actualMessage = message.substring(spaceIndex + 1);
            }
        }

        // 创建消息对象
        Map<String, Object> msg = new HashMap<>();
        msg.put("id", System.currentTimeMillis());
        msg.put("sender", username);
        msg.put("content", actualMessage);
        msg.put("type", isPrivate ? "private" : "public");
        msg.put("recipient", recipient);
        msg.put("timestamp", new Date());

        // 添加到消息列表（限制500条）
        synchronized(messages) {
            if (messages.size() >= 500) {
                messages.remove(0);
            }
            messages.add(msg);
        }

        // 更新在线用户最后活动时间
        Object onlineUsersObj = application.getAttribute("onlineUsers");
        if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;

            if (onlineUsers.containsKey(username)) {
                // 根据实际的数据结构更新最后活动时间
                Object currentUserInfo = onlineUsers.get(username);

                if (currentUserInfo instanceof Long) {
                    // 第一种数据结构
                    onlineUsers.put(username, System.currentTimeMillis());
                } else if (currentUserInfo instanceof Map) {
                    // 第二种数据结构
                    @SuppressWarnings("unchecked")
                    Map<String, Object> userInfo = (Map<String, Object>) currentUserInfo;
                    userInfo.put("lastActive", new Date());
                } else {
                    // 默认处理
                    onlineUsers.put(username, System.currentTimeMillis());
                }
            }
        }

        result.put("success", true);
        result.put("messageId", msg.get("id"));
        result.put("messageData", msg);
        response.getWriter().write(new Gson().toJson(result));
        return;
    }

    // ==================== 用户登录检查 ====================
    String username = (String) session.getAttribute("username");

    // 如果用户未登录，检查是否有POST请求的username参数
    if (username == null) {
        String postUsername = request.getParameter("username");
        if (postUsername != null && !postUsername.trim().isEmpty()) {
            // 处理用户加入
            username = postUsername.trim();

            // 检查用户名是否已存在
            Object onlineUsersObj = application.getAttribute("onlineUsers");
            if (onlineUsersObj == null || !(onlineUsersObj instanceof Map)) {
                Map<String, Object> onlineUsers = Collections.synchronizedMap(new HashMap<>());
                application.setAttribute("onlineUsers", onlineUsers);
                onlineUsersObj = onlineUsers;
            }

            @SuppressWarnings("unchecked")
            Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;

            if (onlineUsers.containsKey(username)) {
                username = username + "_" + (int)(Math.random() * 1000);
            }

            // 添加到在线用户列表
            Map<String, Object> userInfo = new HashMap<>();
            userInfo.put("loginTime", new Date());
            userInfo.put("lastActive", new Date());
            userInfo.put("ip", request.getRemoteAddr());
            onlineUsers.put(username, userInfo);

            // 设置session
            session.setAttribute("username", username);

            // 添加系统消息
            List<Map<String, Object>> messages = (List<Map<String, Object>>) application.getAttribute("messages");
            if (messages == null) {
                messages = Collections.synchronizedList(new ArrayList<>());
                application.setAttribute("messages", messages);
            }

            Map<String, Object> systemMsg = new HashMap<>();
            systemMsg.put("id", System.currentTimeMillis());
            systemMsg.put("sender", "系统");
            systemMsg.put("content", username + " 加入了聊天室");
            systemMsg.put("type", "system");
            systemMsg.put("timestamp", new Date());

            synchronized(messages) {
                if (messages.size() >= 500) {
                    messages.remove(0);
                }
                messages.add(systemMsg);
            }
        } else {
            // 未登录且没有用户名参数，重定向到登录页面
            response.sendRedirect("index.jsp");
            return;
        }
    }

    // ==================== 更新用户最后活动时间 ====================
    Object onlineUsersObj = application.getAttribute("onlineUsers");
    if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
        @SuppressWarnings("unchecked")
        Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;

        if (onlineUsers.containsKey(username)) {
            Object currentUserInfo = onlineUsers.get(username);

            if (currentUserInfo instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> userInfo = (Map<String, Object>) currentUserInfo;
                userInfo.put("lastActive", new Date());
            } else {
                // 如果不是Map结构，则替换为Map结构
                Map<String, Object> userInfo = new HashMap<>();
                userInfo.put("loginTime", new Date());
                userInfo.put("lastActive", new Date());
                userInfo.put("ip", request.getRemoteAddr());
                onlineUsers.put(username, userInfo);
            }
        }
    }

    // ==================== 获取在线用户列表 ====================
    List<String> onlineUserList = new ArrayList<>();
    if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
        @SuppressWarnings("unchecked")
        Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;
        onlineUserList.addAll(onlineUsers.keySet());
        Collections.sort(onlineUserList);
    }

    // ==================== 获取消息历史 ====================
    List<Map<String, Object>> messages = (List<Map<String, Object>>) application.getAttribute("messages");
    List<Map<String, Object>> userMessages = new ArrayList<>();

    if (messages != null) {
        // 只获取当前用户能看到的消息
        for (Map<String, Object> msg : messages) {
            if ("private".equals(msg.get("type"))) {
                String sender = (String) msg.get("sender");
                String recipient = (String) msg.get("recipient");

                // 只有发送者和接收者才能看到私聊消息
                if (username.equals(sender) || username.equals(recipient)) {
                    userMessages.add(msg);
                }
            } else {
                // 公共消息和系统消息
                userMessages.add(msg);
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JSP聊天室 - <%= username %></title>
    <link rel="stylesheet" href="chat.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        .chat-container {
            display: flex;
            height: 100vh;
            padding: 15px;
            gap: 15px;
        }

        /* 侧边栏 */
        .sidebar {
            width: 280px;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            display: flex;
            flex-direction: column;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15);
            overflow: hidden;
        }

        .user-info {
            padding: 20px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }

        .user-avatar {
            width: 60px;
            height: 60px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.8rem;
            margin-bottom: 12px;
        }

        .user-name {
            font-size: 1.3rem;
            font-weight: 600;
            margin-bottom: 5px;
        }

        .user-status {
            font-size: 0.9rem;
            opacity: 0.9;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .user-status-dot {
            width: 8px;
            height: 8px;
            background: #48bb78;
            border-radius: 50%;
        }

        .sidebar-section {
            padding: 20px;
            border-bottom: 1px solid #e2e8f0;
        }

        .sidebar-section h3 {
            color: #2d3748;
            margin-bottom: 15px;
            font-size: 1.1rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .user-list-container {
            flex: 1;
            overflow-y: auto;
            padding: 5px;
        }

        .user-item {
            padding: 12px 15px;
            margin-bottom: 8px;
            background: #f7fafc;
            border-radius: 8px;
            display: flex;
            align-items: center;
            gap: 10px;
            cursor: pointer;
            transition: all 0.2s;
            border: 2px solid transparent;
        }

        .user-item:hover {
            background: #edf2f7;
            transform: translateX(3px);
        }

        .user-item.active {
            background: #e6fffa;
            border-color: #38a169;
        }

        .user-item-avatar {
            width: 36px;
            height: 36px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 0.9rem;
        }

        .user-item-name {
            flex: 1;
            font-weight: 500;
        }

        .user-item-status {
            width: 8px;
            height: 8px;
            background: #48bb78;
            border-radius: 50%;
        }

        .sidebar-actions {
            display: flex;
            flex-direction: column;
            gap: 10px;
            padding: 15px;
        }

        .sidebar-btn {
            padding: 12px;
            border: none;
            border-radius: 8px;
            font-size: 0.95rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .btn-secondary {
            background: #edf2f7;
            color: #4a5568;
        }

        .btn-secondary:hover {
            background: #e2e8f0;
            transform: translateY(-1px);
        }

        .btn-danger {
            background: #fed7d7;
            color: #c53030;
        }

        .btn-danger:hover {
            background: #feb2b2;
            transform: translateY(-1px);
        }

        /* 主聊天区域 */
        .chat-main {
            flex: 1;
            display: flex;
            flex-direction: column;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15);
        }

        .chat-header {
            padding: 20px 25px;
            background: white;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .chat-title {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .chat-title h2 {
            color: #2d3748;
            font-size: 1.5rem;
        }

        .chat-stats {
            display: flex;
            gap: 20px;
            color: #718096;
            font-size: 0.9rem;
        }

        .chat-stats-item {
            display: flex;
            align-items: center;
            gap: 6px;
        }

        /* 消息区域 */
        .messages-container {
            flex: 1;
            padding: 20px;
            overflow-y: auto;
            background: #f8f9fa;
        }

        .message {
            margin-bottom: 18px;
            padding: 16px;
            border-radius: 12px;
            max-width: 80%;
            animation: fadeIn 0.3s ease;
            word-wrap: break-word;
        }

        .message.system {
            background: #fff3cd;
            color: #856404;
            margin: 10px auto;
            text-align: center;
            max-width: 90%;
            border-left: 4px solid #ffc107;
        }

        .message.public {
            background: white;
            border: 1px solid #e2e8f0;
            margin-right: auto;
        }

        .message.private {
            background: #d4edda;
            color: #155724;
            border-left: 4px solid #28a745;
            position: relative;
        }

        .message.private::before {
            content: "🔒 私聊";
            position: absolute;
            top: -8px;
            left: 12px;
            background: #d4edda;
            padding: 0 8px;
            font-size: 0.7rem;
            color: #28a745;
            border-radius: 4px;
        }

        .message.self {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            margin-left: auto;
        }

        .message-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }

        .message-sender {
            font-weight: 600;
            font-size: 0.95rem;
        }

        .message-time {
            font-size: 0.8rem;
            opacity: 0.7;
        }

        .message-content {
            line-height: 1.5;
            margin-bottom: 5px;
        }

        .message-tip {
            font-size: 0.75rem;
            opacity: 0.7;
            text-align: right;
            margin-top: 5px;
        }

        .welcome-message {
            text-align: center;
            padding: 40px 20px;
            color: #718096;
        }

        .welcome-icon {
            font-size: 3rem;
            color: #cbd5e0;
            margin-bottom: 20px;
        }

        /* 输入区域 */
        .input-area {
            padding: 20px;
            background: white;
            border-top: 1px solid #e2e8f0;
        }

        .input-group {
            display: flex;
            gap: 12px;
            align-items: flex-end;
        }

        .message-input {
            flex: 1;
            padding: 14px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            font-size: 1rem;
            resize: none;
            min-height: 55px;
            max-height: 150px;
            transition: border-color 0.3s;
            font-family: 'Segoe UI', sans-serif;
        }

        .message-input:focus {
            outline: none;
            border-color: #667eea;
        }

        .btn-send {
            padding: 14px 28px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 12px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s;
            height: 55px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn-send:hover:not(:disabled) {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .btn-send:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .input-hint {
            font-size: 0.85rem;
            color: #718096;
            margin-top: 8px;
            display: flex;
            justify-content: space-between;
        }

        .typing-indicator {
            color: #667eea;
            font-style: italic;
            min-height: 20px;
        }

        /* 状态栏 */
        .status-bar {
            padding: 12px 20px;
            background: #f8f9fa;
            border-top: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.85rem;
            color: #718096;
        }

        .status-left {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            background: #48bb78;
            border-radius: 50%;
        }

        .status-dot.error {
            background: #e53e3e;
            animation: pulse 1.5s infinite;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        /* 响应式设计 */
        @media (max-width: 1024px) {
            .chat-container {
                flex-direction: column;
                height: auto;
            }

            .sidebar {
                width: 100%;
                max-height: 300px;
            }

            .message {
                max-width: 90%;
            }
        }

        @media (max-width: 768px) {
            .chat-container {
                padding: 10px;
            }

            .chat-header {
                flex-direction: column;
                gap: 15px;
                align-items: flex-start;
            }

            .chat-stats {
                width: 100%;
                justify-content: space-between;
            }

            .input-group {
                flex-direction: column;
            }

            .btn-send {
                width: 100%;
                justify-content: center;
            }
        }

        /* 私聊面板 */
        .private-chat-panel {
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 350px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
            display: none;
            flex-direction: column;
            z-index: 1000;
            border: 1px solid #e2e8f0;
        }

        .private-chat-header {
            padding: 15px 20px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border-radius: 12px 12px 0 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .private-chat-title {
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .private-chat-close {
            background: none;
            border: none;
            color: white;
            cursor: pointer;
            font-size: 1.2rem;
        }

        .private-chat-messages {
            height: 300px;
            padding: 15px;
            overflow-y: auto;
            background: #f8f9fa;
        }

        .private-chat-input {
            padding: 15px;
            border-top: 1px solid #e2e8f0;
        }

        .private-chat-input input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 0.95rem;
        }

        .private-chat-input input:focus {
            outline: none;
            border-color: #667eea;
        }
    </style>
</head>
<body>
<div class="chat-container">
    <!-- 侧边栏 -->
    <div class="sidebar">
        <div class="user-info">
            <div class="user-avatar">
                <i class="fas fa-user"></i>
            </div>
            <div class="user-name"><%= username %></div>
            <div class="user-status">
                <div class="user-status-dot"></div>
                <span>在线</span>
            </div>
        </div>

        <div class="sidebar-section">
            <h3><i class="fas fa-users"></i> 在线用户 (<span id="onlineCount"><%= onlineUserList.size() %></span>)</h3>
            <div class="user-list-container" id="onlineUsers">
                <% for (String user : onlineUserList) {
                    boolean isSelf = user.equals(username);
                %>
                <div class="user-item <%= isSelf ? "active" : "" %>"
                     data-username="<%= user %>"
                     onclick="openPrivateChat('<%= user %>')">
                    <div class="user-item-avatar">
                        <%= user.substring(0, 1).toUpperCase() %>
                    </div>
                    <div class="user-item-name">
                        <%= user %>
                        <% if (isSelf) { %>
                        <span style="font-size: 0.8rem; color: #667eea;">(我)</span>
                        <% } %>
                    </div>
                    <div class="user-item-status"></div>
                </div>
                <% } %>
            </div>
        </div>

        <div class="sidebar-actions">
            <button class="sidebar-btn btn-secondary" onclick="clearChat()">
                <i class="fas fa-trash-alt"></i> 清空聊天
            </button>
            <button class="sidebar-btn btn-secondary" onclick="toggleTheme()">
                <i class="fas fa-moon"></i> 切换主题
            </button>
            <button class="sidebar-btn btn-danger" onclick="logout()">
                <i class="fas fa-sign-out-alt"></i> 退出登录
            </button>
        </div>
    </div>

    <!-- 主聊天区域 -->
    <div class="chat-main">
        <div class="chat-header">
            <div class="chat-title">
                <i class="fas fa-comments"></i>
                <h2>JSP聊天室</h2>
            </div>
            <div class="chat-stats">
                <div class="chat-stats-item">
                    <i class="fas fa-clock"></i>
                    <span id="currentTime">--:--:--</span>
                </div>
                <div class="chat-stats-item">
                    <i class="fas fa-envelope"></i>
                    <span id="messageCount">0</span> 条消息
                </div>
            </div>
        </div>

        <!-- 消息显示区域 -->
        <div class="messages-container" id="messagesContainer">
            <% if (userMessages.isEmpty()) { %>
            <div class="welcome-message">
                <div class="welcome-icon">
                    <i class="fas fa-comments"></i>
                </div>
                <h3>欢迎来到JSP聊天室</h3>
                <p>开始和朋友们聊天吧！</p>
            </div>
            <% } else {
                for (Map<String, Object> msg : userMessages) {
                    String msgType = (String) msg.get("type");
                    String msgSender = (String) msg.get("sender");
                    String msgContent = (String) msg.get("content");
                    Date msgTimestamp = (Date) msg.get("timestamp");
                    String msgRecipient = (String) msg.get("recipient");

                    String msgTime = new SimpleDateFormat("HH:mm:ss").format(msgTimestamp);

                    String messageClass = "message";
                    if ("system".equals(msgType)) {
                        messageClass += " system";
                    } else if ("private".equals(msgType)) {
                        messageClass += " private";
                    } else if (username.equals(msgSender)) {
                        messageClass += " self";
                    } else {
                        messageClass += " public";
                    }
            %>
            <div class="<%= messageClass %>" data-id="<%= msg.get("id") %>">
                <div class="message-header">
                    <div class="message-sender"><%= msgSender %></div>
                    <div class="message-time"><%= msgTime %></div>
                </div>
                <div class="message-content"><%= msgContent %></div>
                <% if ("private".equals(msgType)) { %>
                <div class="message-tip">
                    <% if (username.equals(msgSender)) { %>
                    私聊给: <%= msgRecipient %>
                    <% } else { %>
                    收到私聊
                    <% } %>
                </div>
                <% } %>
            </div>
            <%   }
            } %>
        </div>

        <!-- 输入区域 -->
        <div class="input-area">
            <div class="input-group">
                    <textarea class="message-input" id="messageInput"
                              placeholder="输入消息... (输入 @用户名 进行私聊)"
                              rows="1"></textarea>
                <button class="btn-send" id="sendButton" onclick="sendMessage()">
                    <i class="fas fa-paper-plane"></i> 发送
                </button>
            </div>
            <div class="input-hint">
                <span>提示: 按 Ctrl+Enter 发送消息，双击用户可私聊</span>
                <span class="typing-indicator" id="typingIndicator"></span>
            </div>
        </div>

        <!-- 状态栏 -->
        <div class="status-bar">
            <div class="status-left">
                <div class="status-dot" id="statusDot"></div>
                <span id="connectionStatus">已连接</span>
            </div>
            <div>
                <span id="lastUpdate"><%= new SimpleDateFormat("HH:mm:ss").format(new Date()) %></span>
            </div>
        </div>
    </div>
</div>

<!-- 私聊面板（隐藏，点击用户时显示） -->
<div class="private-chat-panel" id="privateChatPanel">
    <div class="private-chat-header">
        <div class="private-chat-title">
            <i class="fas fa-user-secret"></i>
            <span id="privateChatTarget">用户</span>
        </div>
        <button class="private-chat-close" onclick="closePrivateChat()">
            <i class="fas fa-times"></i>
        </button>
    </div>
    <div class="private-chat-messages" id="privateChatMessages">
        <!-- 私聊消息会在这里显示 -->
    </div>
    <div class="private-chat-input">
        <input type="text" id="privateChatInput"
               placeholder="输入私聊消息..."
               onkeydown="handlePrivateChatKeydown(event)">
    </div>
</div>

<!-- 外部JS文件 -->
<script src="%20chat.js"></script>

<!-- 内联脚本传递数据 -->
<script>
    // 传递服务器数据到前端
    window.chatData = {
        username: '<%= username %>',
        lastMessageId: <%= userMessages.isEmpty() ? 0 : ((Long)userMessages.get(userMessages.size() - 1).get("id")) %>,
        onlineUsers: <%= onlineUserList.size() %>
    };

    // 初始化主题
    const savedTheme = localStorage.getItem('chat_theme');
    if (savedTheme === 'dark') {
        document.body.classList.add('dark-theme');
    }

    // 初始化聊天应用
    document.addEventListener('DOMContentLoaded', function() {
        if (typeof ChatApp !== 'undefined') {
            ChatApp.init();
        }

        // 双击用户列表项快速私聊
        document.querySelectorAll('.user-item').forEach(item => {
            item.addEventListener('dblclick', function(e) {
                e.stopPropagation();
                const username = this.dataset.username;
                const currentUser = '<%= username %>';
                if (username && username !== currentUser) {
                    openPrivateChat(username);
                }
            });
        });
    });

    // 打开私聊面板
    function openPrivateChat(username) {
        if (username === '<%= username %>') return;

        document.getElementById('privateChatTarget').textContent = username;
        document.getElementById('privateChatPanel').style.display = 'flex';

        // 加载私聊历史
        loadPrivateChatHistory(username);
    }

    // 关闭私聊面板
    function closePrivateChat() {
        document.getElementById('privateChatPanel').style.display = 'none';
    }

    // 加载私聊历史
    function loadPrivateChatHistory(targetUser) {
        // 这里可以加载私聊历史
        const panel = document.getElementById('privateChatMessages');
        panel.innerHTML = `<div style="text-align: center; padding: 20px; color: #718096;">
                <i class="fas fa-comments"></i><br>
                开始和 ${targetUser} 私聊
            </div>`;
    }

    // 处理私聊输入
    function handlePrivateChatKeydown(e) {
        if (e.key === 'Enter') {
            const input = document.getElementById('privateChatInput');
            const message = input.value.trim();
            const targetUser = document.getElementById('privateChatTarget').textContent;

            if (message) {
                // 发送私聊消息
                sendPrivateMessage(targetUser, message);
                input.value = '';
            }
        }
    }

    // 发送私聊消息
    function sendPrivateMessage(targetUser, message) {
        const fullMessage = '@' + targetUser + ' ' + message;
        document.getElementById('messageInput').value = fullMessage;
        sendMessage();
        closePrivateChat();
    }

    // 工具函数
    function clearChat() {
        if (confirm('确定要清空聊天记录吗？')) {
            // 这里可以实现清空逻辑
            alert('清空功能需要在服务器端实现');
        }
    }

    function toggleTheme() {
        document.body.classList.toggle('dark-theme');
        localStorage.setItem('chat_theme',
            document.body.classList.contains('dark-theme') ? 'dark' : 'light');
    }

    function logout() {
        if (confirm('确定要退出聊天室吗？')) {
            window.location.href = 'logout.jsp';
        }
    }
</script>
</body>
</html>