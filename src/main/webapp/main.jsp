<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*, java.io.*" %>
<%
  // ====================== 设置响应头 ======================
  response.setCharacterEncoding("UTF-8");
  request.setCharacterEncoding("UTF-8");

  // ====================== 处理AJAX请求 ======================
  String action = request.getParameter("action");

  // 处理统计数据请求
  if ("stats".equals(action)) {
    Map<String, Integer> stats = new HashMap<>();

    // 在线用户数
    Map<String, Map<String, Object>> onlineUsers =
            (Map<String, Map<String, Object>>) application.getAttribute("onlineUsers");
    stats.put("online", onlineUsers != null ? onlineUsers.size() : 0);

    // 消息总数
    List<Map<String, Object>> messages =
            (List<Map<String, Object>>) application.getAttribute("publicMessages");
    stats.put("messages", messages != null ? messages.size() : 0);

    // 返回JSON
    response.setContentType("application/json");
    out.print("{\"online\":" + stats.get("online") + ",\"messages\":" + stats.get("messages") + "}");
    return;
  }

  // 处理获取公聊消息请求
  if ("getMessages".equals(action)) {
    String lastIdStr = request.getParameter("lastId");
    int lastId = 0;
    try {
      lastId = Integer.parseInt(lastIdStr);
    } catch (Exception e) {}

    List<Map<String, Object>> allMessages =
            (List<Map<String, Object>>) application.getAttribute("publicMessages");

    response.setContentType("application/json");
    out.print("{");

    if (allMessages != null && allMessages.size() > lastId) {
      out.print("\"success\":true,");
      out.print("\"hasNew\":true,");
      out.print("\"lastId\":" + allMessages.size() + ",");
      out.print("\"messages\":[");

      for (int i = lastId; i < allMessages.size(); i++) {
        Map<String, Object> msg = allMessages.get(i);
        if (i > lastId) out.print(",");
        out.print("{");
        out.print("\"type\":\"" + msg.get("type") + "\",");
        out.print("\"sender\":\"" + msg.get("sender") + "\",");
        out.print("\"content\":\"" +
                msg.get("content").toString()
                        .replace("\"", "\\\"")
                        .replace("\n", "\\n")
                        .replace("\r", "\\r") + "\",");
        out.print("\"time\":\"" + msg.get("time") + "\"");
        out.print("}");
      }
      out.print("]");
    } else {
      out.print("\"success\":true,");
      out.print("\"hasNew\":false");
    }

    out.print("}");
    return;
  }

  // 处理发送公聊消息请求
  if ("send".equals(action)) {
    String username = (String) session.getAttribute("username");
    String message = request.getParameter("message");

    response.setContentType("application/json");

    if (username == null || username.trim().isEmpty()) {
      out.print("{\"success\":false,\"error\":\"用户未登录\"}");
      return;
    }

    if (message == null || message.trim().isEmpty()) {
      out.print("{\"success\":false,\"error\":\"消息不能为空\"}");
      return;
    }

    message = message.trim();

    // 获取公聊消息列表
    List<Map<String, Object>> messages =
            (List<Map<String, Object>>) application.getAttribute("publicMessages");

    if (messages == null) {
      messages = new ArrayList<Map<String, Object>>();
      application.setAttribute("publicMessages", messages);
    }

    // 创建消息
    Map<String, Object> newMessage = new HashMap<>();
    newMessage.put("type", "public");
    newMessage.put("sender", username);
    newMessage.put("content", message);
    newMessage.put("time", new Date().toLocaleString());

    // 限制消息数量（最多100条）
    synchronized(messages) {
      if (messages.size() >= 100) {
        messages.remove(0);
      }
      messages.add(newMessage);
    }

    // 返回成功
    out.print("{\"success\":true,\"messageId\":" + messages.size() + "}");
    return;
  }

  // 处理获取在线用户请求
  if ("getUsers".equals(action)) {
    Map<String, Map<String, Object>> onlineUsers =
            (Map<String, Map<String, Object>>) application.getAttribute("onlineUsers");

    response.setContentType("application/json");
    out.print("{\"success\":true,\"users\":[");

    if (onlineUsers != null) {
      int count = 0;
      for (String user : onlineUsers.keySet()) {
        if (count > 0) out.print(",");
        out.print("\"" + user + "\"");
        count++;
      }
    }

    out.print("]}");
    return;
  }

  // ====================== 处理用户登录 ======================
  String usernameParam = request.getParameter("username");
  if (usernameParam != null && !usernameParam.trim().isEmpty()) {
    usernameParam = usernameParam.trim();

    // 检查是否已登录
    String currentUser = (String) session.getAttribute("username");
    if (currentUser != null) {
      // 如果已经登录，跳转到聊天页面
      response.sendRedirect("main.jsp");
      return;
    }

    // 设置session
    session.setAttribute("username", usernameParam);
    session.setAttribute("loginTime", new Date());

    // 添加到在线用户列表
    Map<String, Map<String, Object>> onlineUsers =
            (Map<String, Map<String, Object>>) application.getAttribute("onlineUsers");

    if (onlineUsers == null) {
      onlineUsers = new HashMap<String, Map<String, Object>>();
      application.setAttribute("onlineUsers", onlineUsers);
    }

    // 检查用户名是否已存在
    String finalUsername = usernameParam;
    synchronized(onlineUsers) {
      if (onlineUsers.containsKey(finalUsername)) {
        finalUsername = finalUsername + "_" + (int)(Math.random() * 1000);
        session.setAttribute("username", finalUsername);
      }

      Map<String, Object> userInfo = new HashMap<>();
      userInfo.put("loginTime", new Date());
      userInfo.put("lastActive", new Date());
      userInfo.put("ip", request.getRemoteAddr());

      onlineUsers.put(finalUsername, userInfo);
    }

    // 添加系统消息
    List<Map<String, Object>> messages =
            (List<Map<String, Object>>) application.getAttribute("publicMessages");

    if (messages == null) {
      messages = new ArrayList<Map<String, Object>>();
      application.setAttribute("publicMessages", messages);
    }

    Map<String, Object> systemMsg = new HashMap<>();
    systemMsg.put("type", "system");
    systemMsg.put("sender", "系统");
    systemMsg.put("content", finalUsername + " 进入了聊天室");
    systemMsg.put("time", new Date().toLocaleString());

    synchronized(messages) {
      if (messages.size() >= 100) {
        messages.remove(0);
      }
      messages.add(systemMsg);
    }
  }

  // ====================== 检查是否已登录 ======================
  String username = (String) session.getAttribute("username");
  if (username == null || username.trim().isEmpty()) {
    response.sendRedirect("index.jsp");
    return;
  }

  // ====================== 更新最后活动时间 ======================
  Map<String, Map<String, Object>> onlineUsers =
          (Map<String, Map<String, Object>>) application.getAttribute("onlineUsers");

  if (onlineUsers != null) {
    synchronized(onlineUsers) {
      if (onlineUsers.containsKey(username)) {
        Map<String, Object> userInfo = onlineUsers.get(username);
        userInfo.put("lastActive", new Date());
      }

      // 清理超过5分钟不活动的用户
      long currentTime = System.currentTimeMillis();
      List<String> toRemove = new ArrayList<>();

      for (Map.Entry<String, Map<String, Object>> entry : onlineUsers.entrySet()) {
        Map<String, Object> info = entry.getValue();
        Date lastActive = (Date) info.get("lastActive");
        if (lastActive != null && (currentTime - lastActive.getTime() > 5 * 60 * 1000)) {
          toRemove.add(entry.getKey());
        }
      }

      // 移除不活跃用户
      for (String user : toRemove) {
        onlineUsers.remove(user);
      }
    }
  }

  // ====================== 获取在线用户列表 ======================
  List<String> onlineUserList = new ArrayList<>();
  if (onlineUsers != null) {
    synchronized(onlineUsers) {
      onlineUserList.addAll(onlineUsers.keySet());
    }
    Collections.sort(onlineUserList);
  }

  // ====================== 获取消息历史 ======================
  List<Map<String, Object>> messages =
          (List<Map<String, Object>>) application.getAttribute("publicMessages");
  int lastMessageId = 0;
  if (messages != null) {
    lastMessageId = messages.size();
  }
%>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JSP聊天室 - 公聊区 - <%= username %></title>
  <link rel="stylesheet" href="css/style.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
  <style>
    /* 保持原有样式不变，但添加私聊按钮样式 */
    .private-chat-btn {
      margin-left: 10px;
      padding: 2px 8px;
      background: #e3f2fd;
      color: #1976d2;
      border: none;
      border-radius: 4px;
      font-size: 0.8rem;
      cursor: pointer;
      transition: all 0.3s;
    }

    .private-chat-btn:hover {
      background: #bbdefb;
    }

    .user-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .user-info {
      display: flex;
      align-items: center;
      gap: 8px;
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
      <div style="font-size: 0.8rem; color: rgba(255,255,255,0.8);">
        <i class="fas fa-circle" style="color: #4CAF50; font-size: 0.6rem;"></i> 在线
      </div>
    </div>

    <div class="sidebar-section">
      <h3><i class="fas fa-users"></i> 在线用户 (<span id="onlineCount"><%= onlineUserList.size() %></span>)</h3>
      <div class="user-list" id="onlineUsers">
        <% for (String user : onlineUserList) {
          boolean isSelf = user.equals(username);
        %>
        <div class="user-item <%= isSelf ? "active" : "" %>" data-username="<%= user %>">
          <div class="user-info">
            <div class="user-status-indicator"></div>
            <div class="user-name-text">
              <%= user %>
              <% if (isSelf) { %>
              <span style="font-size: 0.8rem; color: #667eea;">(我)</span>
              <% } %>
            </div>
          </div>
          <% if (!isSelf) { %>
          <button class="private-chat-btn" onclick="openPrivateChat('<%= user %>')" title="发起私聊">
            <i class="fas fa-comment"></i>
          </button>
          <% } %>
        </div>
        <% } %>
      </div>
    </div>

    <div class="sidebar-section">
      <h3><i class="fas fa-cog"></i> 操作</h3>
      <div style="display: flex; flex-direction: column; gap: 10px;">
        <button class="btn" onclick="clearChat()" style="background: #edf2f7; color: #4a5568;">
          <i class="fas fa-trash-alt"></i> 清空聊天
        </button>
        <button class="btn" onclick="toggleTheme()" style="background: #edf2f7; color: #4a5568;">
          <i class="fas fa-moon"></i> 切换主题
        </button>
        <button class="btn" onclick="logout()" style="background: #fed7d7; color: #c53030;">
          <i class="fas fa-sign-out-alt"></i> 退出登录
        </button>
      </div>
    </div>
  </div>

  <!-- 聊天区域 -->
  <div class="chat-area">
    <div class="chat-header">
      <div class="chat-title">
        <h2><i class="fas fa-comments"></i> JSP聊天室 - 公聊区</h2>
      </div>
      <div style="color: #718096; font-size: 0.9rem;">
        最后更新: <span id="lastUpdate"><%= new Date().toLocaleTimeString() %></span>
      </div>
    </div>

    <!-- 消息显示 -->
    <div class="messages-container" id="messagesContainer">
      <%
        if (messages != null) {
          for (Map<String, Object> msg : messages) {
            String msgType = (String) msg.get("type");
            String msgSender = (String) msg.get("sender");
            String msgContent = (String) msg.get("content");
            String msgTime = (String) msg.get("time");

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
      <div class="<%= messageClass %>">
        <div class="message-header">
          <div class="message-sender"><%= msgSender %></div>
          <div class="message-time"><%= msgTime %></div>
        </div>
        <div class="message-content"><%= msgContent %></div>
      </div>
      <%
          }
        }
      %>
    </div>

    <!-- 输入区域 -->
    <div class="input-area">
      <div class="input-group">
                    <textarea class="message-input" id="messageInput"
                              placeholder="输入消息..."
                              rows="1"></textarea>
        <button class="btn-send" id="sendButton" onclick="sendMessage()">
          <i class="fas fa-paper-plane"></i> 发送
        </button>
      </div>
      <div style="font-size: 0.85rem; color: #718096; margin-top: 8px;">
        提示: 按 Ctrl+Enter 发送消息 | 点击用户列表的<i class="fas fa-comment" style="margin: 0 5px;"></i>按钮发起私聊
      </div>
    </div>

    <!-- 状态栏 -->
    <div class="status-bar">
      <div>
        <span id="connectionStatus">已连接</span>
      </div>
      <div>
        消息总数: <span id="messageCount"><%= lastMessageId %></span>
      </div>
    </div>
  </div>
</div>

<!-- 外部JS文件 -->
<script src="js/chat.js"></script>

<!-- 内联脚本 -->
<script>
  // 传递服务器数据到JavaScript
  window.chatConfig = {
    username: '<%= username %>',
    lastMessageId: <%= lastMessageId %>,
    isPrivate: false
  };

  // 打开私聊窗口
  function openPrivateChat(targetUser) {
    const url = 'private.jsp?targetUser=' + encodeURIComponent(targetUser);
    window.open(url, '_blank', 'width=800,height=600,menubar=no,toolbar=no');
  }

  // 初始化聊天应用
  document.addEventListener('DOMContentLoaded', function() {
    // 加载保存的主题
    const savedTheme = localStorage.getItem('chat_theme');
    if (savedTheme === 'dark') {
      document.body.classList.add('dark-theme');
    }

    // 初始化
    if (typeof ChatApp !== 'undefined') {
      ChatApp.init();
    }
  });
</script>
</body>
</html>