# Rake tasks

```bash
# Manual execution
rails games:fetch_new

# Check statistics
rails games:stats

# Start the job queue (for recurring jobs)
rails solid_queue:start
```


## Reset DB

```bash
rails db:drop
rails db:migrate
rails games:fetch_new
```