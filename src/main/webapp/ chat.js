/**
 * JSP聊天室 - 前端交互脚本
 * 修复版：解决消息发送和显示问题
 */

const ChatApp = {
    // 配置
    config: {
        pollInterval: 2000,
        username: window.chatData?.username || '匿名用户',
        lastMessageId: window.chatData?.lastMessageId || 0,
        serverUrl: window.location.href.split('?')[0]
    },

    // 状态
    state: {
        pollTimer: null,
        isTyping: false,
        isConnected: true,
        typingTimer: null,
        privateChatTarget: null,
        onlineUsers: []
    },

    // 初始化
    init: function() {
        console.log('JSP聊天室初始化，用户:', this.config.username);

        // 检查必要元素
        if (!this.checkElements()) {
            console.error('缺少必要的DOM元素');
            return;
        }

        // 绑定事件
        this.bindEvents();

        // 开始轮询
        this.startPolling();

        // 初始化界面
        this.initUI();

        console.log('聊天室初始化完成');
    },

    // 检查必要元素
    checkElements: function() {
        const required = ['messageInput', 'sendButton', 'messagesContainer'];
        for (const id of required) {
            if (!document.getElementById(id)) {
                console.error('缺少元素:', id);
                return false;
            }
        }
        return true;
    },

    // 绑定事件
    bindEvents: function() {
        const messageInput = document.getElementById('messageInput');
        const sendButton = document.getElementById('sendButton');

        // 发送消息
        sendButton.addEventListener('click', () => this.sendMessage());

        // 消息输入框事件
        messageInput.addEventListener('keydown', (e) => {
            // Ctrl+Enter 发送
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                e.preventDefault();
                this.sendMessage();
            }

            // 输入检测
            this.handleTyping();
        });

        // 自动调整高度
        messageInput.addEventListener('input', function() {
            this.style.height = 'auto';
            this.style.height = Math.min(this.scrollHeight, 150) + 'px';
        });

        // 页面可见性变化
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.onPageHidden();
            } else {
                this.onPageVisible();
            }
        });

        // 网络状态变化
        window.addEventListener('online', () => this.onNetworkOnline());
        window.addEventListener('offline', () => this.onNetworkOffline());
    },

    // 初始化界面
    initUI: function() {
        // 更新时间显示
        this.updateTime();
        setInterval(() => this.updateTime(), 1000);

        // 更新消息计数
        this.updateMessageCount();

        // 滚动到底部
        this.scrollToBottom();

        // 设置用户名
        const usernameElement = document.querySelector('.user-name');
        if (usernameElement) {
            usernameElement.textContent = this.config.username;
        }
    },

    // 发送消息
    sendMessage: function() {
        const input = document.getElementById('messageInput');
        const message = input.value.trim();

        if (!message) {
            this.showNotification('请输入消息内容', 'error');
            return;
        }

        if (message.length > 500) {
            this.showNotification('消息过长（最多500字符）', 'error');
            return;
        }

        // 禁用输入和按钮
        input.disabled = true;
        document.getElementById('sendButton').disabled = true;

        // 发送请求
        const formData = new URLSearchParams();
        formData.append('message', message);

        fetch('sendMessage.jsp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            },
            body: formData,
            credentials: 'same-origin'
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('HTTP错误: ' + response.status);
                }
                return response.json();
            })
            .then(data => {
                if (data.success) {
                    // 立即显示自己发送的消息
                    if (data.messageData) {
                        this.addMessageToUI({
                            id: data.messageData.id,
                            sender: data.messageData.sender,
                            content: data.messageData.content,
                            type: data.messageData.type,
                            time: new Date(data.messageData.timestamp).toLocaleTimeString([],
                                {hour: '2-digit', minute:'2-digit', second:'2-digit'}),
                            isSelf: true,
                            recipient: data.messageData.recipient
                        });
                    }

                    // 清空输入框
                    input.value = '';
                    input.style.height = 'auto';

                    // 重置输入状态
                    this.resetTypingState();

                    // 播放发送音效
                    this.playSound('send');

                    // 更新消息计数
                    this.updateMessageCount();

                    // 自动滚动到底部
                    this.scrollToBottom();
                } else {
                    this.showNotification('发送失败: ' + (data.error || '未知错误'), 'error');
                }
            })
            .catch(error => {
                console.error('发送失败:', error);
                this.showNotification('发送失败: ' + error.message, 'error');
            })
            .finally(() => {
                // 重新启用输入
                input.disabled = false;
                document.getElementById('sendButton').disabled = false;
                input.focus();
            });
    },

    // 开始轮询
    startPolling: function() {
        // 清除已有定时器
        if (this.state.pollTimer) {
            clearInterval(this.state.pollTimer);
        }

        // 立即执行一次
        this.pollMessages();

        // 设置定时器
        this.state.pollTimer = setInterval(() => {
            this.pollMessages();
        }, this.config.pollInterval);

        this.updateConnectionStatus('已连接');
    },

    // 轮询消息
    pollMessages: function() {
        // 使用专门的获取消息接口
        fetch('getMessages.jsp?lastId=' + this.config.lastMessageId + '&_=' + Date.now(), {
            credentials: 'same-origin',
            headers: {
                'Cache-Control': 'no-cache'
            }
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('HTTP错误: ' + response.status);
                }
                return response.json();
            })
            .then(data => {
                if (data.success) {
                    // 处理新消息
                    if (data.messages && data.messages.length > 0) {
                        let hasNewMessages = false;

                        data.messages.forEach(msg => {
                            // 检查是否是自己刚发送的消息（已经显示过）
                            const isOwnMessage = msg.sender === this.config.username;
                            const messageExists = document.querySelector(`.message[data-id="${msg.id}"]`);

                            if (!messageExists) {
                                this.addMessageToUI(msg);
                                hasNewMessages = true;

                                // 播放新消息音效（除了自己发送的消息）
                                if (!isOwnMessage) {
                                    this.playSound('receive');

                                    // 显示桌面通知
                                    if (document.hidden) {
                                        this.showDesktopNotification(msg);
                                    }
                                }
                            }
                        });

                        // 更新最后消息ID
                        if (data.lastId) {
                            this.config.lastMessageId = data.lastId;
                        }

                        // 自动滚动
                        if (hasNewMessages && this.shouldAutoScroll()) {
                            this.scrollToBottom();
                        }

                        // 更新最后更新时间
                        this.updateLastUpdateTime();
                    }

                    // 更新在线用户列表
                    if (data.onlineUsers) {
                        this.updateOnlineUsersUI(data.onlineUsers);
                    }

                    // 更新连接状态
                    this.updateConnectionStatus('已连接');
                    this.state.isConnected = true;
                }
            })
            .catch(error => {
                console.error('轮询失败:', error);
                this.updateConnectionStatus('连接错误');
                this.state.isConnected = false;
            });
    },

    // 更新在线用户界面
    updateOnlineUsersUI: function(users) {
        const container = document.getElementById('onlineUsers');
        const countElement = document.getElementById('onlineCount');

        if (!container) return;

        // 更新计数
        if (countElement) {
            countElement.textContent = users.length;
        }

        // 保存在线用户
        this.state.onlineUsers = users;

        // 排序（自己在前面）
        const sortedUsers = [...users].sort((a, b) => {
            if (a === this.config.username) return -1;
            if (b === this.config.username) return 1;
            return a.localeCompare(b);
        });

        // 更新列表
        container.innerHTML = '';

        sortedUsers.forEach(user => {
            const isSelf = user === this.config.username;
            const firstLetter = user.substring(0, 1).toUpperCase();

            const userItem = document.createElement('div');
            userItem.className = isSelf ? 'user-item active' : 'user-item';
            userItem.dataset.username = user;

            userItem.innerHTML = `
                <div class="user-item-avatar">${firstLetter}</div>
                <div class="user-item-name">
                    ${this.escapeHtml(user)}
                    ${isSelf ? '<span style="font-size: 0.8rem; color: #667eea;">(我)</span>' : ''}
                </div>
                <div class="user-item-status"></div>
            `;

            // 双击事件
            if (!isSelf) {
                userItem.addEventListener('dblclick', () => {
                    this.openPrivateChat(user);
                });
            }

            container.appendChild(userItem);
        });
    },

    // 添加消息到界面
    addMessageToUI: function(msg) {
        const container = document.getElementById('messagesContainer');
        if (!container) return;

        // 移除欢迎消息（如果有）
        const welcomeMsg = container.querySelector('.welcome-message');
        if (welcomeMsg) {
            welcomeMsg.remove();
        }

        // 检查消息是否已存在
        if (container.querySelector(`.message[data-id="${msg.id}"]`)) {
            return; // 消息已存在，避免重复添加
        }

        // 创建消息元素
        const messageDiv = document.createElement('div');

        // 确定消息类型和样式
        let messageClass = 'message';
        let messageTip = '';

        if (msg.type === 'system') {
            messageClass += ' system';
        } else if (msg.type === 'private') {
            messageClass += ' private';
            if (msg.sender === this.config.username) {
                messageTip = `<div class="message-tip">私聊给: ${this.escapeHtml(msg.recipient)}</div>`;
            } else {
                messageTip = `<div class="message-tip">收到私聊</div>`;
            }
        } else if (msg.sender === this.config.username) {
            messageClass += ' self';
        } else {
            messageClass += ' public';
        }

        // 格式化内容
        const content = this.formatMessageContent(msg.content);

        messageDiv.className = messageClass;
        messageDiv.dataset.id = msg.id || 'msg_' + Date.now();
        messageDiv.innerHTML = `
        <div class="message-header">
            <div class="message-sender">${this.escapeHtml(msg.sender)}</div>
            <div class="message-time">${msg.time || new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'})}</div>
        </div>
        <div class="message-content">${content}</div>
        ${messageTip}
    `;

        // 添加到容器
        container.appendChild(messageDiv);

        // 更新消息计数
        this.updateMessageCount();

        // 滚动到底部
        this.scrollToBottom();
    },

    // 打开私聊
    openPrivateChat: function(username) {
        this.state.privateChatTarget = username;

        // 显示私聊面板
        const panel = document.getElementById('privateChatPanel');
        const targetElement = document.getElementById('privateChatTarget');

        if (panel && targetElement) {
            targetElement.textContent = username;
            panel.style.display = 'flex';

            // 聚焦输入框
            const input = document.getElementById('privateChatInput');
            if (input) {
                setTimeout(() => input.focus(), 100);
            }
        }
    },

    // 处理输入状态
    handleTyping: function() {
        if (!this.state.isTyping) {
            this.state.isTyping = true;
            this.updateTypingIndicator();
        }

        // 清除之前的定时器
        if (this.state.typingTimer) {
            clearTimeout(this.state.typingTimer);
        }

        // 设置新定时器
        this.state.typingTimer = setTimeout(() => {
            this.state.isTyping = false;
            this.updateTypingIndicator();
        }, 2000);
    },

    // 重置输入状态
    resetTypingState: function() {
        this.state.isTyping = false;
        this.updateTypingIndicator();

        if (this.state.typingTimer) {
            clearTimeout(this.state.typingTimer);
            this.state.typingTimer = null;
        }
    },

    // 更新输入指示器
    updateTypingIndicator: function() {
        const indicator = document.getElementById('typingIndicator');
        if (indicator) {
            indicator.textContent = this.state.isTyping ? '正在输入...' : '';
        }
    },

    // 更新连接状态
    updateConnectionStatus: function(status) {
        const statusElement = document.getElementById('connectionStatus');
        const dotElement = document.getElementById('statusDot');

        if (statusElement) {
            statusElement.textContent = status;
        }

        if (dotElement) {
            if (status === '已连接') {
                dotElement.className = 'status-dot';
                dotElement.style.backgroundColor = '#48bb78';
            } else {
                dotElement.className = 'status-dot error';
                dotElement.style.backgroundColor = '#e53e3e';
            }
        }
    },

    // 页面隐藏
    onPageHidden: function() {
        console.log('页面隐藏，暂停轮询');
        if (this.state.pollTimer) {
            clearInterval(this.state.pollTimer);
            this.state.pollTimer = null;
        }
    },

    // 页面显示
    onPageVisible: function() {
        console.log('页面显示，恢复轮询');
        this.updateTime();
        this.updateLastUpdateTime();

        if (!this.state.pollTimer) {
            this.startPolling();
        }
    },

    // 网络恢复
    onNetworkOnline: function() {
        this.showNotification('网络已恢复', 'success');
        this.updateConnectionStatus('已连接');

        if (!this.state.pollTimer) {
            this.startPolling();
        }
    },

    // 网络断开
    onNetworkOffline: function() {
        this.showNotification('网络连接已断开', 'error');
        this.updateConnectionStatus('网络断开');

        if (this.state.pollTimer) {
            clearInterval(this.state.pollTimer);
            this.state.pollTimer = null;
        }
    },

    // 工具函数
    updateTime: function() {
        const element = document.getElementById('currentTime');
        if (element) {
            element.textContent = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
        }
    },

    updateLastUpdateTime: function() {
        const element = document.getElementById('lastUpdate');
        if (element) {
            element.textContent = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
        }
    },

    updateMessageCount: function() {
        const element = document.getElementById('messageCount');
        const messages = document.querySelectorAll('.message');

        if (element) {
            element.textContent = messages.length;
        }
    },

    scrollToBottom: function() {
        const container = document.getElementById('messagesContainer');
        if (container) {
            container.scrollTop = container.scrollHeight;
        }
    },

    shouldAutoScroll: function() {
        const container = document.getElementById('messagesContainer');
        if (!container) return false;

        const threshold = 100; // 像素
        return container.scrollHeight - container.scrollTop - container.clientHeight <= threshold;
    },

    formatMessageContent: function(content) {
        if (!content) return '';

        // 转义HTML
        let formatted = this.escapeHtml(content);

        // 转换URL为链接
        formatted = formatted.replace(
            /(https?:\/\/[^\s]+)/g,
            '<a href="$1" target="_blank" rel="noopener">$1</a>'
        );

        // 转换@用户
        formatted = formatted.replace(
            /@(\w+)/g,
            '<span class="user-mention">@$1</span>'
        );

        // 简单表情转换
        const emojiMap = {
            ':)': '😊', ':-)': '😊',
            ':(': '😔', ':-(': '😔',
            ':D': '😃', ':-D': '😃',
            ':P': '😛', ':-P': '😛',
            ';)': '😉', ';-)': '😉',
            ':O': '😮', ':-O': '😮',
            '<3': '❤️',
            ':*': '😘', ':-*': '😘'
        };

        Object.keys(emojiMap).forEach(emoji => {
            const regex = new RegExp(this.escapeRegExp(emoji), 'g');
            formatted = formatted.replace(regex, emojiMap[emoji]);
        });

        return formatted;
    },

    escapeHtml: function(text) {
        if (!text) return '';

        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    escapeRegExp: function(string) {
        return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    },

    playSound: function(type) {
        // 简单的音效实现
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();

            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);

            if (type === 'send') {
                oscillator.frequency.value = 800;
                gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
                gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);
                oscillator.start(audioContext.currentTime);
                oscillator.stop(audioContext.currentTime + 0.1);
            } else if (type === 'receive') {
                oscillator.frequency.value = 600;
                gainNode.gain.setValueAtTime(0.15, audioContext.currentTime);
                gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.15);
                oscillator.start(audioContext.currentTime);
                oscillator.stop(audioContext.currentTime + 0.15);
            }
        } catch (e) {
            // 忽略音频错误
        }
    },

    showNotification: function(message, type = 'info') {
        // 创建通知元素
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;

        const icon = type === 'success' ? 'check-circle' :
            type === 'error' ? 'exclamation-circle' : 'info-circle';

        notification.innerHTML = `
            <div style="display: flex; align-items: center; gap: 10px;">
                <i class="fas fa-${icon}"></i>
                <span>${this.escapeHtml(message)}</span>
            </div>
        `;

        // 添加到页面
        document.body.appendChild(notification);

        // 3秒后移除
        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, 3000);
    },

    showDesktopNotification: function(msg) {
        if (!('Notification' in window) || Notification.permission !== 'granted') {
            return;
        }

        const title = msg.type === 'private' ?
            `私聊来自 ${msg.sender}` :
            `新消息来自 ${msg.sender}`;

        const options = {
            body: msg.content.length > 50 ?
                msg.content.substring(0, 50) + '...' :
                msg.content,
            icon: '/favicon.ico',
            tag: 'chat-message'
        };

        new Notification(title, options);
    }
};

// 页面加载完成后初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        if (typeof ChatApp !== 'undefined') {
            ChatApp.init();
        }
    });
} else {
    // DOM已经加载完成
    if (typeof ChatApp !== 'undefined') {
        ChatApp.init();
    }
}