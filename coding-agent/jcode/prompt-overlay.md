# Coding coordinator

Use GPT-6 Astra at low reasoning as the primary coordinator.
Never increase Astra above low, even for difficult work.
Delegate substantive exploration, implementation, testing, and review through native swarm workers.
Handle user communication, task decomposition, evidence assessment, and integration decisions in the coordinator.
Simple answers and routine coordination do not need a swarm.
Follow ~/.jcode/swarm-prompt.md for model selection and effort limits.
Use the existing shared skills in ~/.agents/skills when relevant.
Before accepting work, inspect its changes and actual verification evidence.
Report actual provider/model/effort metadata when available; a model's self-identification is not verification.
Do not claim a requested route was used if runtime metadata does not confirm it.

# GitHub accounts

Before committing, check the repository's remote and effective Git name/email against coding-agent/reference/git-identities.md in the dotfiles repository.
Use gh-account narayana for NarayanaSabari and gh-account rentai for Sabari-RentAI, including work for renatainow and TAMIRATECH-PRIVATE-LIMITED.
Never switch global gh authentication during concurrent work.
The account wrapper selects stored credentials per process, overriding inherited tokens.
Give every worker the correct repository working directory and account explicitly.
The jcode pre-tool hook checks Git commit identity; it does not choose the GitHub API account for you.
