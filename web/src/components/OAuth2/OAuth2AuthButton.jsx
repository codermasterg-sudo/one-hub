import { useState } from 'react';
import PropTypes from 'prop-types';
import {
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  AlertTitle,
  Box,
  Typography,
  Link,
  CircularProgress,
  Stack
} from '@mui/material';
import { IconBrandOauth } from '@tabler/icons-react';
import { API } from 'utils/api';
import { showError, showSuccess } from 'utils/common';

/**
 * OAuth2 授权按钮组件
 * 通用的 OAuth2 授权流程处理
 */
function OAuth2AuthButton({ provider, onSuccess, disabled = false, buttonText, buttonVariant = 'contained' }) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [authData, setAuthData] = useState(null);
  const [code, setCode] = useState('');

  // 步骤 1：获取授权 URL
  const handleStartAuth = async () => {
    if (!provider) {
      showError('未指定 Provider');
      return;
    }

    setLoading(true);
    try {
      const res = await API.get('/api/oauth2/auth_url', {
        params: { provider }
      });

      if (res.data.success) {
        const data = res.data.data;
        setAuthData(data);
        setOpen(true);

        // 自动打开授权页面
        window.open(data.auth_url, '_blank', 'width=600,height=700');
      } else {
        showError(res.data.message || '获取授权链接失败');
      }
    } catch (error) {
      console.error('Get OAuth2 auth URL error:', error);
      showError('获取授权链接失败，请检查网络连接');
    } finally {
      setLoading(false);
    }
  };

  // 步骤 2：交换 refresh token
  const handleExchange = async () => {
    if (!code.trim()) {
      showError('请输入授权码');
      return;
    }

    setLoading(true);
    try {
      const res = await API.post('/api/oauth2/exchange', {
        provider: authData.provider,
        code: code.trim(),
        state: authData.state
      });

      if (res.data.success) {
        showSuccess('授权成功！');
        const refreshToken = res.data.data.refresh_token;

        // 回调父组件
        if (onSuccess) {
          onSuccess(refreshToken);
        }

        // 关闭对话框并重置状态
        handleClose();
      } else {
        showError(res.data.message || '授权失败');
      }
    } catch (error) {
      console.error('OAuth2 exchange error:', error);
      showError('授权失败，请检查授权码是否正确');
    } finally {
      setLoading(false);
    }
  };

  // 关闭对话框
  const handleClose = () => {
    setOpen(false);
    setCode('');
    setAuthData(null);
  };

  // 重新打开授权页面
  const handleReopenAuth = () => {
    if (authData && authData.auth_url) {
      window.open(authData.auth_url, '_blank', 'width=600,height=700');
    }
  };

  return (
    <>
      <Button
        variant={buttonVariant}
        color="primary"
        startIcon={<IconBrandOauth />}
        onClick={handleStartAuth}
        disabled={disabled || loading}
      >
        {loading ? '加载中...' : buttonText || 'OAuth2 授权'}
      </Button>

      <Dialog
        open={open}
        onClose={handleClose}
        maxWidth="sm"
        fullWidth
        aria-labelledby="oauth2-dialog-title"
      >
        <DialogTitle id="oauth2-dialog-title">
          OAuth2 授权
          {authData?.use_pkce && (
            <Typography variant="caption" display="block" color="text.secondary">
              使用 PKCE 安全授权
            </Typography>
          )}
        </DialogTitle>

        <DialogContent>
          <Stack spacing={2}>
            <Alert severity="info">
              <AlertTitle>授权步骤</AlertTitle>
              <ol style={{ margin: 0, paddingLeft: '20px' }}>
                <li>点击下方链接打开授权页面</li>
                <li>在授权页面登录并同意授权</li>
                <li>复制授权后获得的授权码</li>
                <li>将授权码粘贴到下方输入框</li>
                <li>点击"确认授权"按钮完成</li>
              </ol>
            </Alert>

            {authData?.code_format === 'code#state' && (
              <Alert severity="warning">
                <strong>注意：</strong>授权码格式为 <code>code#state</code>，请完整复制（包含 # 符号）
              </Alert>
            )}

            <Box>
              <Typography variant="body2" gutterBottom>
                授权链接：
              </Typography>
              <Link
                href={authData?.auth_url}
                target="_blank"
                rel="noopener noreferrer"
                sx={{
                  display: 'inline-block',
                  maxWidth: '100%',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap'
                }}
              >
                点击此处打开授权页面
              </Link>
              <Button size="small" onClick={handleReopenAuth} sx={{ ml: 1 }}>
                重新打开
              </Button>
            </Box>

            <TextField
              fullWidth
              label="授权码"
              placeholder={authData?.code_format === 'code#state' ? '例如：abc123#xyz789' : '粘贴授权码'}
              value={code}
              onChange={(e) => setCode(e.target.value)}
              disabled={loading}
              multiline
              rows={2}
              helperText="请完整复制授权后显示的授权码"
            />
          </Stack>
        </DialogContent>

        <DialogActions>
          <Button onClick={handleClose} disabled={loading}>
            取消
          </Button>
          <Button
            onClick={handleExchange}
            variant="contained"
            disabled={loading || !code.trim()}
            startIcon={loading && <CircularProgress size={20} />}
          >
            {loading ? '授权中...' : '确认授权'}
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
}

OAuth2AuthButton.propTypes = {
  provider: PropTypes.string.isRequired,
  onSuccess: PropTypes.func.isRequired,
  disabled: PropTypes.bool,
  buttonText: PropTypes.string,
  buttonVariant: PropTypes.oneOf(['text', 'outlined', 'contained'])
};

export default OAuth2AuthButton;
