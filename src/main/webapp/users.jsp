<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*, com.google.gson.Gson" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");

    String action = request.getParameter("action");
    Map<String, Object> result = new HashMap<>();

    if ("stats".equals(action)) {
        // 返回统计数据
        Object onlineUsersObj = application.getAttribute("onlineUsers");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> messages =
            (List<Map<String, Object>>) application.getAttribute("messages");

        int onlineCount = 0;
        if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> onlineUsers = (Map<String, Object>) onlineUsersObj;
            onlineCount = onlineUsers.size();
        }

        result.put("online", onlineCount);
        result.put("messages", messages != null ? messages.size() : 0);
        result.put("users", 0); // 如果需要，可以添加用户注册功能

        response.getWriter().write(new Gson().toJson(result));
        return;
    }

    // 获取当前用户
    String username = (String) session.getAttribute("username");

    if (username == null || username.trim().isEmpty()) {
        result.put("success", false);
        result.put("error", "用户未登录");
        response.getWriter().write(new Gson().toJson(result));
        return;
    }

    // 获取在线用户列表
    Object onlineUsersObj = application.getAttribute("onlineUsers");

    List<String> onlineUserList = new ArrayList<>();
    if (onlineUsersObj != null && onlineUsersObj instanceof Map) {
        // 清理长时间不活动的用户（5分钟）
        long currentTime = System.currentTimeMillis();
        List<String> toRemove = new ArrayList<>();

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

            // 添加用户离开的系统消息
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> messages =
                (List<Map<String, Object>>) application.getAttribute("messages");

            if (messages != null) {
                Map<String, Object> leaveMsg = new HashMap<>();
                leaveMsg.put("type", "system");
                leaveMsg.put("sender", "系统");
                leaveMsg.put("content", user + " 因长时间不活动已自动退出");
                leaveMsg.put("timestamp", new Date());

                if (messages.size() >= 500) {
                    messages.remove(0);
                }
                messages.add(leaveMsg);
            }
        }
    }

    // 按字母顺序排序
    Collections.sort(onlineUserList);

    result.put("success", true);
    result.put("users", onlineUserList);
    result.put("count", onlineUserList.size());

    response.getWriter().write(new Gson().toJson(result));
%>