<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*, com.google.gson.Gson" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");

    Map<String, Object> result = new HashMap<>();

    try {
        // 获取当前用户
        String username = (String) session.getAttribute("username");

        if (username == null || username.trim().isEmpty()) {
            result.put("success", false);
            result.put("error", "用户未登录");
            response.getWriter().write(new Gson().toJson(result));
            return;
        }

        // 获取消息内容
        String message = request.getParameter("message");

        if (message == null || message.trim().isEmpty()) {
            result.put("success", false);
            result.put("error", "消息内容不能为空");
            response.getWriter().write(new Gson().toJson(result));
            return;
        }

        message = message.trim();

        // 获取消息列表
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> messages =
            (List<Map<String, Object>>) application.getAttribute("messages");

        if (messages == null) {
            messages = new ArrayList<Map<String, Object>>();
            application.setAttribute("messages", messages);
        }

        // 检查是否是私聊消息（格式: @用户名 消息内容）
        String messageType = "public";
        String recipient = null;

        if (message.startsWith("@")) {
            int spaceIndex = message.indexOf(" ");
            if (spaceIndex > 1) {
                recipient = message.substring(1, spaceIndex);
                String actualMessage = message.substring(spaceIndex + 1);

                // 检查接收者是否在线
                Object onlineUsersObj = application.getAttribute("onlineUsers");
                boolean recipientOnline = false;

                if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;
                    if (onlineUsers.containsKey(recipient)) {
                        recipientOnline = true;
                    }
                }

                if (recipientOnline) {
                    // 私聊消息
                    messageType = "private";

                    // 为接收者创建私聊消息副本
                    Map<String, Object> privateMsg = new HashMap<>();
                    privateMsg.put("type", "private");
                    privateMsg.put("sender", username);
                    privateMsg.put("recipient", recipient);
                    privateMsg.put("content", actualMessage);
                    privateMsg.put("timestamp", new Date());
                    privateMsg.put("id", System.currentTimeMillis());

                    // 添加到消息列表
                    if (messages.size() >= 500) {
                        messages.remove(0);
                    }
                    messages.add(privateMsg);

                    result.put("success", true);
                    result.put("message", "私聊消息已发送");
                    result.put("messageData", privateMsg); // 添加消息数据用于实时显示
                    response.getWriter().write(new Gson().toJson(result));
                    return;
                } else {
                    // 接收者不在线
                    result.put("success", false);
                    result.put("error", recipient + " 不在线");
                    response.getWriter().write(new Gson().toJson(result));
                    return;
                }
            }
        }

        // 创建新消息（公共消息）
        Map<String, Object> newMessage = new HashMap<>();
        newMessage.put("type", messageType);
        newMessage.put("sender", username);
        newMessage.put("content", message);
        newMessage.put("timestamp", new Date());
        newMessage.put("id", System.currentTimeMillis());

        // 限制消息数量（最多500条）
        if (messages.size() >= 500) {
            messages.remove(0);
        }

        messages.add(newMessage);

        // 更新用户最后活动时间
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
        result.put("message", "消息发送成功");
        result.put("messageData", newMessage); // 添加消息数据用于实时显示
        response.getWriter().write(new Gson().toJson(result));

    } catch (Exception e) {
        e.printStackTrace();
        result.put("success", false);
        result.put("error", "服务器内部错误: " + e.getMessage());
        response.getWriter().write(new Gson().toJson(result));
    }
%>