from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import urllib.parse

# This simulates a PVE database
VMS = []

class MockPVE(BaseHTTPRequestHandler):
    def do_GET(self):
        # Simulates checking if a VM exists
        if "/api2/json/nodes/pve/qemu" in self.path:
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"data": VMS}).encode())
            
    def do_POST(self):
        # Simulates creating a VM
        if "/api2/json/nodes/pve/qemu/9000/clone" in self.path:
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode()
            params = urllib.parse.parse_qs(body)
            
            new_vm = {
                "vmid": params.get("newid", [""])[0],
                "name": params.get("name", [""])[0],
                "status": "running"
            }
            VMS.append(new_vm)
            print(f"[MOCK API] Created VM: {new_vm['name']}")
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"data": "UPID:12345"}).encode())

    def do_DELETE(self):
        # Simulates destroying a VM
        if "/api2/json/nodes/pve/qemu/" in self.path:
            vmid = self.path.split('/')[-1].split('?')[0]
            global VMS
            VMS = [vm for vm in VMS if vm["vmid"] != vmid]
            print(f"[MOCK API] Destroyed VM ID: {vmid}")
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"data": "UPID:67890"}).encode())

print("Mock Proxmox API running on http://localhost:8006")
HTTPServer(('0.0.0.0', 8006), MockPVE).serve_forever()
