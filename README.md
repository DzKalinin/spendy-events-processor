Deploy:
1. Install google CLI: https://cloud.google.com/sdk/docs/install#installation_instructions.
2. Login to gcloud and use needed google project.
3. Run ```gcloud functions deploy put_expense --runtime ruby30 --trigger-http --allow-unauthenticated``` .

Run locally
1. Update application.yml and google_key.json with correct values.
2. Run ```bundle exec functions-framework-ruby --target=put_expense --port=3000```
