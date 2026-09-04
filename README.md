# 🌐 DNSConfig

A powershell-based DNS management tool for Windows.

⚡ Switch between well-known DNS providers, configure custom DNS servers, test DNS latency, flush the DNS cache, or reset your network stack entirely — all from one interactive menu.

## ✨ Features

- 🔍 Detects your active network interface, local IP, gateway, MAC address, public IP, and currently configured DNS at a glance
- 🚀 One-key switching between built-in DNS providers (Cloudflare, Google, Quad9, Shecan, Electro, TCI, Localhost)
- ✏️ Manual DNS configuration with IPv4 validation
- ⏱️ Latency test against every provider, with a clear OK/Timeout status for each
- 🔄 Switch back to automatic DNS (DHCP)
- 🧹 Flush the DNS cache
- 🛠️ Full network reset (Winsock catalog, TCP/IP stack, Windows Firewall, DNS cache, IP release/renew) with a step-by-step progress checklist and clear success/failure reporting for every step

## 📋 Requirements

- 🪟 Windows 10/11 (or Windows Server 2016+)
- 💻 PowerShell 5.1 (built into Windows) or PowerShell 7+
- 🔑 Administrator rights (the script elevates itself automatically — you'll get a UAC prompt)

## 🚀 Getting started

Windows tags every file downloaded from the internet with a "Mark of the Web," and by default PowerShell blocks unsigned scripts carrying that tag. The one-time command below removes that friction permanently for your user account, so you never have to think about it again.

### 1️⃣ One-time setup (do this once, ever)

Open any PowerShell window and run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
```

No admin rights needed — this only affects your own user account, not the whole machine. **Trade-off, stated plainly:** this tells Windows to stop checking execution policy and Mark-of-the-Web on *any* `.ps1` script you run from now on, not just this one. If you'd rather keep more protection, use `RemoteSigned` instead of `Bypass` — but then you'll need to run `Unblock-File .\DNSConfig.ps1` once per downloaded copy of the script, since `RemoteSigned` still blocks unsigned scripts carrying the Mark of the Web.

### 2️⃣ Running it

1. 📥 Download latest version of `DNSConfig.ps1` from the [Releases](../../releases) page into any folder.
2. ▶️ Right-click it → **Run with PowerShell**. Do this any time you want to open the tool.
3. ✅ Approve the UAC prompt — the tool needs administrator rights to change network settings.

That one-time setup step is what makes step 2 always work cleanly, with no errors or prompts, every time you run it. 🎉

## 🎮 Usage

Once running, use the number keys shown in the menu:

- `1`–`7` — instantly switch to that DNS provider
- `8` — test latency of every provider (green ✓ for OK, red ✗ for timeout)
- `9` — enter a custom primary/secondary DNS manually
- `10` — revert to automatic DNS (DHCP)
- `11` — flush the DNS cache
- `12` — full network reset (use if your network is badly misconfigured)
- `0` — quit

## 📝 Notes

- 📡 The latency test uses ICMP ping; some networks/servers block ICMP, which will show as `✗ Timeout` even if the DNS service itself is reachable — this reflects the network path, not necessarily the DNS provider's health.
- 🛠️ If the network reset reports a failure on the TCP/IP stack step, it's most often caused by third-party antivirus, firewall, or VPN software holding a lock on part of the network stack — temporarily disabling it before resetting usually resolves this.
- 🔁 A restart is recommended after any network reset to fully apply the changes.

## 📄 License

MIT — see [LICENSE](LICENSE).
