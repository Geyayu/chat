<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*, java.text.*" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JSP聊天室 - 登录</title>
    <link rel="stylesheet" href="chat.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        .login-container {
            max-width: 400px;
            margin: 100px auto;
            padding: 40px;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }

        .logo {
            font-size: 4rem;
            color: #667eea;
            margin-bottom: 20px;
            animation: bounce 2s infinite;
        }

        h1 {
            color: #2d3748;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .subtitle {
            color: #718096;
            margin-bottom: 30px;
        }

        .form-group {
            margin-bottom: 20px;
            text-align: left;
        }

        label {
            display: block;
            margin-bottom: 8px;
            color: #4a5568;
            font-weight: 500;
        }

        input[type="text"] {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 10px;
            font-size: 1rem;
            transition: border-color 0.3s;
        }

        input[type="text"]:focus {
            outline: none;
            border-color: #667eea;
        }

        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }

        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }

        .stats {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e2e8f0;
            display: flex;
            justify-content: space-around;
        }

        .stat {
            text-align: center;
        }

        .stat-number {
            font-size: 1.5rem;
            font-weight: 600;
            color: #667eea;
        }

        .stat-label {
            font-size: 0.9rem;
            color: #718096;
        }

        @keyframes bounce {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }
    </style>
</head>
<body>
<div class="login-container">
    <div class="logo">
        <i class="fas fa-comments"></i>
    </div>

    <h1>JSP 聊天室</h1>
    <p class="subtitle">修复版 - 消息实时更新</p>

    <form action="chat.jsp" method="post">
        <div class="form-group">
            <label for="username">
                <i class="fas fa-user"></i> 请输入昵称
            </label>
            <input type="text" id="username" name="username"
                   value="用户<%= (int)(Math.random()*1000) %>"
                   required minlength="2" maxlength="20">
        </div>

        <button type="submit">
            <i class="fas fa-sign-in-alt"></i> 进入聊天室
        </button>
    </form>

    <div class="stats">
        <div class="stat">
            <div class="stat-number" id="onlineCount">0</div>
            <div class="stat-label">当前在线</div>
        </div>
        <div class="stat">
            <div class="stat-number" id="messageCount">0</div>
            <div class="stat-label">累计消息</div>
        </div>
    </div>
</div>

<script>
    // 从服务器获取统计数据
    fetch('chat.jsp?action=stats')
        .then(response => response.json())
        .then(data => {
            if (data && data.success) {
                document.getElementById('onlineCount').textContent = data.online || 0;
                document.getElementById('messageCount').textContent = data.messages || 0;
            }
        })
        .catch(e => console.log('获取统计数据失败'));
</script>
</body>
</html>