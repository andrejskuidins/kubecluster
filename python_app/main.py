
from kubernetes.client.rest import ApiException
from kubernetes import client, config
from google.cloud import storage
import datetime

config.load_incluster_config() 
pod_name = "elasticsearch-logging-0"
def elk_logs():
    api_instance = client.CoreV1Api()
    api_response = api_instance.read_namespaced_pod_log(name=pod_name, namespace='kube-system')
    f = open("elasticsearch-logging-0.log", "w")
    f.write(api_response)
    f.close()
    return 'Logs written to file'

def upload_blob():
  ct = str(datetime.datetime.now().timestamp())
  """Uploads a file to the bucket."""
  storage_client = storage.Client()
  bucket = storage_client.get_bucket('andrejs-kube1-test-cluster-bucket')
  blob = bucket.blob('elasticsearch-logging-0'+ct)

  blob.upload_from_filename('elasticsearch-logging-0.log')

  print('File {} uploaded to {}.'.format(
      'elasticsearch-logging-0.log',
      'elasticsearch-logging-0'+ct))

upload_blob()
