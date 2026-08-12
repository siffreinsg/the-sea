# Infrastructure

- [ ] Fix `/opt/the-sea`'s git-triggered pull on TB

# Observability

- [ ] Repair Grafana collection
    - [ ] Restore going-merry collection
    - [ ] Filter noise out of logs, metrics and traces
    - [ ] Collect traces from Komodo
    - [ ] Add blackbox LAN probes from Baratie's Alloy

# Services

- [ ] Media
    - [ ] Deploy Bazarr
    - [ ] Deploy Wizarr
    - [ ] Fix cross-seed on qui
    - [ ] Deploy Suggestarr
    - [ ] Deploy Pulsarr
    - [ ] Deploy Prunerr
- [ ] Actual rule pipeline
    - [ ] Port rules from the encrypted budget — [work](work/actual-rules-port.md)
    - [ ] Mine rules from history — [work](work/actual-rules-mining.md)
    - [ ] Categorize leftovers with an LLM — [work](work/actual-llm-categorization.md)
- [ ] Files and documents
    - [ ] Detect conflicting Syncthing files with an n8n automation
    - [ ] Deploy FileBrowser
- [ ] Deploy Digarr for Spotify support

# Security

- [ ] Audit the edge
    - [ ] Scan from off-network and read the Oracle VCN security list
- [ ] Track IPs in Grafana and alert on anomalies
