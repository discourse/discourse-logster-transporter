# discourse-logster-transporter

Chains a custom logger to Logster allowing you to report Logster logs from a
Discourse instance over to another Discourse instance via HTTP.

## Configuration

### Receiver

On the instance that is meant to receive the logs, simply [install the plugin](https://meta.discourse.org/t/install-plugins-in-discourse/19157)
and configure a secret key by running `rails runner 'SiteSetting.logster_transporter_key = SecureRandom.hex'`.

### Sender

On the instance that you want to ship logs from, you'll have to first [install the plugin](<(https://meta.discourse.org/t/install-plugins-in-discourse/19157)>).

Next set the following environment variable on the instance. Example:

```
LOGSTER_TRANSPORTER_ROOT_URL: https://test.mydiscourse.org
LOGSTER_TRANSPORTER_KEY: <SiteSetting.logster_transporter_key configured on the receiver>
```
