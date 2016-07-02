use Mix.Config

config :logger, level: :info

config :bamboo,
  mailgun_base_uri: "http://localhost:8765/",
  mandrill_base_uri: "http://localhost:8765/",
  sendgrid_base_uri: "http://localhost:8765"
