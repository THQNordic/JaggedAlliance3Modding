Libs.Network = "sync"
config.LocalToNetPause = true

config.SupportGameRecording = not not Platform.trailer
config.EnableGameRecording = false
config.DisableGameRecordingAutoSave = true

config.SwarmHost = "ja3.haemimontgames.com"
config.SwarmPort = Platform.test and 46399 or 46301

config.SwarmConnect = "reconnect" -- false, "ping", "reconnect"
config.SwarmWorld = "Zulu"
if Platform.demo then
	config.SwarmWorld = "Zulu Demo"
end

config.NetStatusText = true
config.NetGossip = true
config.NetCheckUpdates = true

config.PasswordMinLen = 6
config.PasswordMaxLen = 128
config.PasswordHasMixedDigits = false
config.PasswordAllowCommon = true

config.AllowInvites = true

config.EnableVoiceChat = true

config.SwarmPublicKey = config.SwarmPublicKey or {}
config.SwarmPublicKey["ja3.haemimontgames.com"] = RSACreateKeyNoErr(
[[-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1O2yNBjdAxDK7IxVNhQQ
BzIsyR6lJoHsCmXXhs1u77IzCwPAw25WCPXJJBxM3Ip3NorYp/S/sajeJtv1ZldU
n2rr4TxzzSOamRRNDVtyvv7EmgiWUleUGon+nP3yR23gtSQVKXyB+LUrBfAlJeKN
Eb5E8rN+l7fwqn3a7wZO9xeAzPnenQZ8Rb5RdG/WA6RUlGpIeweutrmS9LnWoTrC
JxrSnLMMJVg825OBY8H1zekltTdS9jYLO8jmmEallEd5Di5UNVadP/KwJxZptsFa
+3V/mpfGGtYWL7GTmfGfwpn4Jgyh8v+AWZfpMA01IzHP4+Wx/ICsRFP7SAVEvhhh
fQIDAQAB
-----END PUBLIC KEY-----]])