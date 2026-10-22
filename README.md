# Billing Management System

Ứng dụng quản lý khách hàng, sản phẩm, hóa đơn và thanh toán; triển khai toàn bộ stack bằng Docker Compose. Dự án gồm Flask, PostgreSQL, pgAdmin, Nginx HTTPS, Prometheus, Grafana, Loki và Promtail.

## Sơ đồ dịch vụ

```text
Trình duyệt ── HTTPS :8443 ──> Nginx ──> Flask/Gunicorn ──> PostgreSQL
                                  │             │
                                  └──── metrics ┴──> Prometheus ──> Grafana
Docker logs ──> Promtail ──> Loki ────────────────────┘
pgAdmin ──> PostgreSQL
```

Mạng `edge` phục vụ Nginx; `data` và `observability` là mạng nội bộ Docker. Mạng `host_access` kết nối riêng pgAdmin, Grafana và Prometheus với các cổng chỉ bind vào `127.0.0.1`. PostgreSQL không publish cổng ra máy host.

## Yêu cầu

- Docker Desktop có Docker Compose v2, hoặc Docker Engine + Compose v2.
- Tối thiểu 4 GB RAM được cấp cho Docker Desktop; stack gồm nhiều dịch vụ.
- Windows PowerShell hoặc Bash.

## Khởi chạy lần đầu

Trong thư mục `billing-management-system`:

**Windows PowerShell**

```powershell
.\scripts\init-env.ps1
docker compose config
docker compose up --build -d
docker compose ps
```

**Linux/macOS**

```bash
sh scripts/init-env.sh
docker compose config
docker compose up --build -d
docker compose ps
```

Script tạo `.env` với mật khẩu ngẫu nhiên bằng bộ sinh số ngẫu nhiên mật mã của hệ điều hành. Không chia sẻ, commit hoặc gửi tệp `.env`. `.gitignore` đã loại trừ tệp này. Nếu `.env` đã tồn tại, script không ghi đè mật khẩu.

Ứng dụng tự tạo schema PostgreSQL. Nếu có `billing.db` SQLite cũ cạnh `docker-compose.yml`, dữ liệu được nhập một lần vào PostgreSQL khi database mới còn rỗng; file SQLite được mount chỉ đọc. Khi không có file SQLite, ứng dụng tạo dữ liệu mẫu. Database PostgreSQL dùng volume bền vững.

## Địa chỉ truy cập

| Thành phần | Địa chỉ | Đăng nhập |
|---|---|---|
| Website qua Nginx HTTPS | <https://localhost:8443> | Không cần |
| pgAdmin | <http://127.0.0.1:5050> | `PGADMIN_DEFAULT_EMAIL` và `PGADMIN_DEFAULT_PASSWORD` trong `.env` |
| Grafana | <http://127.0.0.1:3000> | `GRAFANA_ADMIN_USER` và `GRAFANA_ADMIN_PASSWORD` trong `.env` |
| Prometheus | <http://127.0.0.1:9090> | Không cần; chỉ bind localhost |

HTTPS sử dụng chứng chỉ tự ký được tạo bên trong container Nginx khi khởi động; trình duyệt sẽ cảnh báo vì đây không phải chứng chỉ của CA công cộng. Chấp nhận cảnh báo chỉ trong môi trường demo cục bộ. Không tái sử dụng cấu hình/chứng chỉ này cho hệ thống Internet.

Trong pgAdmin, chọn server **Billing PostgreSQL**. Khi được hỏi mật khẩu kết nối database, nhập giá trị `APP_DB_PASSWORD` trong `.env`. Tài khoản ứng dụng PostgreSQL `billing_app` không phải superuser.

## Kiểm tra hoạt động

```bash
docker compose ps
docker compose logs --tail=100 billing nginx db prometheus loki promtail
```

- Website: `https://localhost:8443`; API kiểm tra DB: `https://localhost:8443/health`.
- Kiểm tra HTTPS headers trên PowerShell: `curl.exe -k -I https://localhost:8443/`; trong kết quả cần thấy `Strict-Transport-Security`, `Content-Security-Policy`, `X-Frame-Options` và `X-Content-Type-Options`.
- Prometheus: vào **Status → Targets**, kiểm tra `billing-web`, `nginx`, `postgres`, `containers` là `UP`.
- Grafana: mở dashboard **Billing / Billing System Overview**. Nguồn Prometheus và Loki được provision tự động.
- Loki: Grafana → **Explore** → nguồn dữ liệu Loki; chọn thời gian gần đây, sau đó thử:

```logql
{compose_service="billing"}
{compose_service="nginx"} |= "GET"
{compose_service="db"} |~ "(?i)error|fatal"
```

Hai truy vấn đầu hiển thị request của ứng dụng và reverse proxy; truy vấn cuối tìm lỗi PostgreSQL. Có thể tạo traffic bằng cách mở website hoặc gọi API rồi chọn khoảng thời gian 15 phút gần nhất.

Promtail lấy Docker container logs thông qua Docker socket và chỉ giữ các service có tên trong allowlist của `infra/promtail/promtail-config.yml`. Docker socket có quyền kiểm soát lớn đối với Docker host dù mount chỉ đọc; đây là giới hạn bảo mật cần lưu ý trong demo. Không chạy stack này trên máy dùng chung hoặc máy chủ production mà chưa thiết kế collector ít đặc quyền hơn.

**Lưu ý vòng đời:** Promtail là thành phần legacy/EOL theo lộ trình Grafana; rubric yêu cầu cụ thể Promtail nên cấu hình này giữ Promtail cho mục đích học tập. Với hệ thống mới hoặc production, ưu tiên Grafana Alloy và cập nhật image về phiên bản được hỗ trợ.

## Kiến trúc và hardening

- Flask chạy bằng Gunicorn dưới UID/GID không phải root, filesystem chỉ đọc, `no-new-privileges` và bỏ Linux capabilities.
- Nginx dùng image unprivileged, TLS 1.2/1.3, reverse proxy và security headers: HSTS, CSP, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`.
- PostgreSQL không publish cổng; database nằm trong network nội bộ. Có role riêng cho app và exporter, mật khẩu sinh ngẫu nhiên.
- `data` và `observability` khai báo `internal: true`. Dashboard/DB admin chỉ mở trên loopback.
- cAdvisor chỉ nhận các capability đọc/quan sát cần cho host metrics; PostgreSQL và pgAdmin không tham gia mạng observability nếu không cần.
- Prometheus, Grafana, Loki và PostgreSQL lưu dữ liệu bằng named volumes. PostgreSQL có healthcheck; ứng dụng chờ DB sẵn sàng trước khi khởi chạy.
- `.env`, SQLite database, virtualenv và dữ liệu cục bộ bị loại khỏi Git.

## Vận hành

```bash
docker compose stop
docker compose start
docker compose down
docker compose logs -f billing
```

`docker compose down` giữ lại volumes. Không dùng `docker compose down -v` trừ khi chủ động xóa dữ liệu PostgreSQL, Grafana, Prometheus, Loki và pgAdmin. Đổi mật khẩu trong `.env` sau khi volume PostgreSQL đã khởi tạo không tự thay đổi password trong database; cần xoay vòng mật khẩu bằng SQL/pgAdmin và cập nhật các service liên quan.

## Cấu trúc chính

```text
app.py                       Flask API, PostgreSQL/SQLite adapter, /health, /metrics
Dockerfile                   Image Flask/Gunicorn non-root
docker-compose.yml           Toàn bộ services, networks, volumes và healthchecks
infra/nginx/                 Image Nginx unprivileged có OpenSSL, HTTPS, headers
infra/postgres/              Tạo role ứng dụng và metrics
infra/pgadmin/               Cấu hình server đăng ký trước
infra/prometheus/             Scrape targets cho web, Nginx, PostgreSQL, cAdvisor
infra/grafana/                Provision datasource và dashboard
infra/loki/                   Lưu trữ log tập trung
infra/promtail/               Thu thập Docker logs, giới hạn service allowlist
scripts/                      Sinh .env an toàn
BAO-CAO.html                  Báo cáo A4 17 trang, gồm ảnh giao diện local và runtime
evidence/                     Ảnh chụp thật; ảnh khách hàng đã làm mờ thông tin
```

## GitHub và bàn giao

Repository được đồng bộ tại <https://github.com/dtc245200669-bot/github-lab>, nhánh `main`; đã có ba commit riêng cho web/reverse proxy, monitoring và logging/báo cáo. Không commit `.env`, mật khẩu hoặc SQLite database. Lịch sử commit hiện có:

```bash
92255f5 feat: deploy hardened billing app behind HTTPS Nginx
c3c2da0 feat: add Prometheus and Grafana monitoring
f909bbc feat: add Loki logging and deployment report
```

Tài liệu [`BAO-CAO.html`](./BAO-CAO.html) có 17 trang A4 và phân biệt ảnh local SQLite với ảnh runtime Docker Compose. Minh chứng runtime gồm website HTTPS (`evidence/06-website-https.png`), hai ảnh Grafana dashboard (`evidence/07-grafana-dashboard.png`, `evidence/11-grafana-database-container.png`), pgAdmin schema (`evidence/08-pgadmin-schema.png`), Loki Explore (`evidence/09-loki-explore.png`) và Prometheus Targets (`evidence/05-prometheus-targets.png`). Hai ảnh truy vấn LogQL bổ sung nằm ở `evidence/12-logql-nginx.png` và `evidence/13-logql-database-errors.png`. Stack đã được build; HTTPS health trả HTTP 200, cả năm targets UP, pgAdmin kết nối PostgreSQL và Loki trả log qua LogQL. Trước khi nộp, bổ sung thông tin cá nhân còn trống trên bìa/trang ký và chạy lại lệnh demo trên máy trình bày.
