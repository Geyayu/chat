<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*, com.google.gson.Gson" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");

    // 获取当前用户
    String username = (String) session.getAttribute("username");
    Map<String, Object> result = new HashMap<>();

    if (username == null || username.trim().isEmpty()) {
        result.put("success", false);
        result.put("error", "用户未登录");
        response.getWriter().write(new Gson().toJson(result));
        return;
    }

    // 获取最后一条消息的ID
    int lastId = 0;
    try {
        lastId = Integer.parseInt(request.getParameter("lastId"));
    } catch (NumberFormatException e) {
        lastId = 0;
    }

    // 获取消息列表
    @SuppressWarnings("unchecked")
    List<Map<String, Object>> allMessages =
        (List<Map<String, Object>>) application.getAttribute("messages");

    List<Map<String, Object>> newMessages = new ArrayList<>();
    int currentLastId = 0;

    if (allMessages != null) {
        currentLastId = allMessages.size();

        // 获取从lastId开始的新消息
        for (int i = lastId; i < allMessages.size(); i++) {
            Map<String, Object> msg = allMessages.get(i);

            // 如果是私聊消息，只显示发送给当前用户或由当前用户发送的消息
            if ("private".equals(msg.get("type"))) {
                String recipient = (String) msg.get("recipient");
                String sender = (String) msg.get("sender");

                if (username.equals(recipient) || username.equals(sender)) {
                    newMessages.add(msg);
                }
            } else {
                // 公共消息和系统消息
                newMessages.add(msg);
            }
        }
    }

    // 获取在线用户列表
    Object onlineUsersObj = application.getAttribute("onlineUsers");

    List<String> onlineUserList = new ArrayList<>();
    if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
        // 清理长时间不活动的用户（5分钟）
        long currentTime = System.currentTimeMillis();
        List<String> toRemove = new ArrayList<>();

        // 安全地处理不同类型的onlineUsers数据结构
        @SuppressWarnings("unchecked")
        Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;

        for (Map.Entry<String, Object> entry : onlineUsers.entrySet()) {
            String user = entry.getKey();
            Object value = entry.getValue();

            long lastActiveTime = 0;

            // 检查value的类型
            if (value instanceof Long) {
                // 第一种数据结构: Map<String, Long>
                lastActiveTime = (Long) value;
            } else if (value instanceof Map) {
                // 第二种数据结构: Map<String, Map<String, Object>>
                @SuppressWarnings("unchecked")
                Map<String, Object> userInfo = (Map<String, Object>) value;
                Object lastActiveObj = userInfo.get("lastActive");

                if (lastActiveObj instanceof Date) {
                    lastActiveTime = ((Date) lastActiveObj).getTime();
                } else if (lastActiveObj instanceof Long) {
                    lastActiveTime = (Long) lastActiveObj;
                }
            }

            // 检查用户是否超时
            if (currentTime - lastActiveTime > 5 * 60 * 1000) {
                toRemove.add(user);
            } else {
                onlineUserList.add(user);
            }
        }

        // 移除不活跃用户
        for (String user : toRemove) {
            onlineUsers.remove(user);
        }
    }

    // 更新当前用户的活动时间
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
    result.put("messages", newMessages);
    result.put("lastId", currentLastId);
    result.put("onlineUsers", onlineUserList);

    response.getWriter().write(new Gson().toJson(result));
%>