from locust import HttpUser, task, between

class WebsiteUser(HttpUser):
  wait_time = between(0.5, 1)

  @task
  def get_page(self):
    self.client.get(url="/CIIC:Spring:2023", verify=False)