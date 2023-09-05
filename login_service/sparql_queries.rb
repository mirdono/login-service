require_relative '../lib/mu/auth-sudo'

USERS_GRAPH = ENV['USERS_GRAPH'] || "http://mu.semte.ch/application"
SESSIONS_GRAPH = ENV['SESSIONS_GRAPH'] || "http://mu.semte.ch/application"

module LoginService
  module SparqlQueries

    def select_salted_password_and_salt_by_nickname(nickname)
      query =  " SELECT ?uuid ?uri ?password ?salt WHERE {"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     ?uri a <#{RDF::Vocab::FOAF.OnlineAccount}> ; "
      query += "        <#{RDF::Vocab::FOAF.accountName}> #{nickname.downcase.sparql_escape} ; "
      query += "        <#{MU_ACCOUNT.status}> <#{MU_ACCOUNT['status/active']}> ; "
      query += "        <#{MU_ACCOUNT.password}> ?password ; "
      query += "        <#{MU_ACCOUNT.salt}> ?salt ; "
      query += "        <#{MU_CORE.uuid}> ?uuid . "
      query += "   }"
      query += " }"
      Mu::AuthSudo.query(query)
    end

    def select_inactive_account_by_nickname(nickname)
      query =  " SELECT ?uuid ?uri WHERE {"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     ?uri a <#{RDF::Vocab::FOAF.OnlineAccount}> ; "
      query += "        <#{RDF::Vocab::FOAF.accountName}> #{nickname.downcase.sparql_escape} ; "
      query += "        <#{MU_ACCOUNT.status}> <#{MU_ACCOUNT['status/inactive']}> ; "
      query += "        <#{MU_CORE.uuid}> ?uuid . "
      query += "     FILTER NOT EXISTS {?uri <#{MU_ACCOUNT.password}> ?password}"
      query += "   }"
      query += " }"
      Mu::AuthSudo.query(query)
    end

    # Adapted from registration service
    def update_account_with_password(account_uri, hashed_password, account_salt, nickname)
      # Insert new password and salt
      now = DateTime.now
      query =  " INSERT DATA {"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     <#{account_uri}> "
      unless hashed_password.nil? or account_salt.nil?
        query += "                    <#{MU_ACCOUNT.password}> #{hashed_password.sparql_escape} ;"
        query += "                    <#{MU_ACCOUNT.salt}> #{account_salt.sparql_escape} ;"
      end
      unless nickname.nil?
        query += "                    <#{RDF::Vocab::FOAF.accountName}> #{nickname.downcase.sparql_escape} ;"
      end
      query += "                      <#{RDF::Vocab::DC.modified}> #{now.sparql_escape} ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    # Adapted from registration service
    def activate_account(account_uri)
      # Delete old status
      query =  " WITH <#{USERS_GRAPH}> "
      query += " DELETE {"
      query += "   <#{account_uri}> <#{MU_ACCOUNT.status}> ?status ;"
      query += "                    <#{RDF::Vocab::DC.modified}> ?modified ."
      query += " }"
      query += " WHERE {"
      query += "   <#{account_uri}> <#{MU_ACCOUNT.status}> ?status ;"
      query += "                    <#{RDF::Vocab::DC.modified}> ?modified ."
      query += " }"
      Mu::AuthSudo.update(query)

      # Set new active status
      now = DateTime.now
      query =  " INSERT DATA {"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     <#{account_uri}> <#{MU_ACCOUNT.status}> <#{MU_ACCOUNT['status/active']}> ;"
      query += "                      <#{RDF::Vocab::DC.modified}> #{now.sparql_escape} ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def remove_old_sessions(session)
      query =  " DELETE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{MU_SESSION.account}> ?account ;"
      query += "                  <#{MU_CORE.uuid}> ?id ; "
      query += "                  <#{MU_EXT.sessionRole}> ?role . "
      query += "   }"
      query += " }"
      query += " WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{MU_SESSION.account}> ?account ;"
      query += "                  <#{MU_CORE.uuid}> ?id . "
      query += "     OPTIONAL { <#{session}> <#{MU_EXT.sessionRole}> ?role . } "
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def insert_new_session_for_account(account, session_uri, session_id, roles)
      query =  " INSERT DATA {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session_uri}> <#{MU_SESSION.account}> <#{account}> ;"
      query += "                      <#{MU_CORE.uuid}> #{session_id.sparql_escape} ."
      roles.each do |role|
        query += "   <#{session_uri}> <#{MU_EXT.sessionRole}> #{role.sparql_escape} ."
      end
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def select_account_by_session(session)
      query =  " SELECT ?uuid ?account WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{MU_SESSION.account}> ?account ."
      query += "   }"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     ?account <#{MU_CORE.uuid}> ?uuid ;"
      query += "              a <#{RDF::Vocab::FOAF.OnlineAccount}> ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.query(query)
    end

    def select_current_session(account)
      query =  " SELECT ?uri WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     ?uri <#{MU_SESSION.account}> <#{account}> ;"
      query += "          <#{MU_CORE.uuid}> ?id . "
      query += "   }"
      query += " }"
      Mu::AuthSudo.query(query)
    end

    def delete_current_session(account)
      query = " DELETE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     ?session <#{MU_SESSION.account}> <#{account}> ;"
      query += "              <#{MU_CORE.uuid}> ?id ; "
      query += "              <#{MU_EXT.sessionRole}> ?role . "
      query += "   }"
      query += " }"
      query += " WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     ?session <#{MU_SESSION.account}> <#{account}> ;"
      query += "              <#{MU_CORE.uuid}> ?id . "
      query += "     OPTIONAL { ?session <#{MU_EXT.sessionRole}> ?role . } "
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def update_modified(session, modified = DateTime.now)
      query = " DELETE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{RDF::Vocab::DC.modified}> ?modified ."
      query += "   }"
      query += " }"
      query += " WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{RDF::Vocab::DC.modified}> ?modified ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)

      query =  " INSERT DATA {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{RDF::Vocab::DC.modified}> #{modified.sparql_escape} ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def select_roles(account_id)
      query =  " SELECT ?role WHERE {"
      query += "   GRAPH <#{USERS_GRAPH}> {"
      query += "     <#{account_id}> a <#{RDF::Vocab::FOAF.OnlineAccount}> ;"
      query += "                     <#{MU_EXT.role}> ?role ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.query(query)
    end
  end
end
