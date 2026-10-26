param([int]$Port = 8765)
$root = (Split-Path -Parent $MyInvocation.MyCommand.Path)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "PrintStyle Academy: http://127.0.0.1:$Port/"
Write-Host "Close this window to stop the local server."

$mime = @{
  '.html'='text/html; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'
  '.svg'='image/svg+xml'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.webp'='image/webp'
  '.txt'='text/plain; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.ico'='image/x-icon'
}
$rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

try {
  while ($listener.Server.IsBound) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $stream.ReadTimeout = 5000
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
      $requestLine = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }
      while (($line = $reader.ReadLine()) -ne $null -and $line -ne '') { }

      $parts = $requestLine.Split(' ')
      if ($parts.Count -lt 2 -or $parts[0] -ne 'GET') {
        $body = [System.Text.Encoding]::UTF8.GetBytes('Method not allowed')
        $status = '405 Method Not Allowed'
        $type = 'text/plain; charset=utf-8'
      } else {
        $rawPath = $parts[1].Split('?')[0]
        try { $decoded = [Uri]::UnescapeDataString($rawPath) } catch { $decoded = '/' }
        if ($decoded -eq '/' -or [string]::IsNullOrWhiteSpace($decoded)) { $decoded = '/index.html' }
        $relative = $decoded.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $full = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
          $body = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
          $status = '403 Forbidden'; $type = 'text/plain; charset=utf-8'
        } elseif (Test-Path $full -PathType Leaf) {
          $body = [System.IO.File]::ReadAllBytes($full)
          $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
          $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
          $status = '200 OK'
        } else {
          $body = [System.Text.Encoding]::UTF8.GetBytes('Not found')
          $status = '404 Not Found'; $type = 'text/plain; charset=utf-8'
        }
      }
      $header = "HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
      $hb = [System.Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($hb,0,$hb.Length)
      if ($body.Length -gt 0) { $stream.Write($body,0,$body.Length) }
      $stream.Flush()
    } catch {
      # Keep the local server alive if one browser request fails.
    } finally {
      if ($stream) { $stream.Dispose() }
      $client.Dispose()
    }
  }
} finally {
  $listener.Stop()
}
