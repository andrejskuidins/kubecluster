# Prometheus + Grafana + Apache

Running Apache and Apache Exporter containers on same pod.

## Apache

- https://hub.docker.com/_/httpd
- https://httpd.apache.org/docs/2.4/mod/mod_status.html

```sh
kubectl create configmap apache-httpdconf --from-file=httpd.conf -n kube-system
```

## Apache-exporter

- https://github.com/Lusitaniae/apache_exporter#readme

  Default settings, e.g. http://localhost/server-status?auto, are sufficient
