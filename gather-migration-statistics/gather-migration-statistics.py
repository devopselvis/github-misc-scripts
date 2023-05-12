import csv
import sys
import requests
import subprocess
import argparse

parser = argparse.ArgumentParser(description='Create reports from GitHub Enterprise')   
parser.add_argument('--token', help='GitHub token')
parser.add_argument('--enterprise', help='GitHub Enterprise slug')
parser.add_argument('--public_repos', action='store_true', help='Create public repo report')
parser.add_argument('--all_repos', action='store_true', help='Create all repo report')
parser.add_argument('--secrets', action='store_true', help='Create secrets report')
parser.add_argument('--repo_stats', action='store_true', help='Create repo stats report')
parser.add_argument('--environments', action='store_true', help='Create environments report')
args = parser.parse_args()

headers = {
    #'Authorization': 'Bearer ' + sys.argv[1]
    'Authorization': 'Bearer ' + args.token
}

#def run_query(query):
#    request = requests.post('https://api.github.com/graphql', json={'query': query}, headers=headers)
#    if request.status_code == 200:
#        return request.json()
#    else:
#        raise Exception("Query failed to run by returning code of {}. {}".format(request.status_code, query))

def run_query_with_vars(query, variables=None):
    request = requests.post('https://api.github.com/graphql', json={'query': query, 'variables': variables}, headers=headers)
    if request.status_code == 200:
        return request.json()
    else:
        raise Exception("Query failed to run by returning code of {}. {}".format(request.status_code, query))

def get_all_orgs_query(after_cursor=None):
    query = """
    query allOrgs ($enterpriseSlug: String!, $afterCursor: String) {
        enterprise(slug: $enterpriseSlug) {
            organizations(first: 100 after: $afterCursor) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                nodes {
                    name
                    login
                }
            }
        }
    }
    """
    variables = {
        "enterpriseSlug": args.enterprise,
        "afterCursor": after_cursor
    }
    return query, variables

def get_all_public_repos_query(org_login, after_cursor=None):
    query = """
    query allRepos($orgLogin: String!, $afterCursor: String) {
        organization(login: $orgLogin) {
            repositories(first: 100, after: $afterCursor, privacy: PUBLIC) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                nodes {
                    name
                    url
                }
            }
        }
    }
    """
    variables = {
        "orgLogin": org_login,
        "afterCursor": after_cursor
    }
    return query, variables

def get_all_repos_query(org_login, after_cursor=None):
    query = """
    query allRepos($orgLogin: String!, $afterCursor: String) {
        organization(login: $orgLogin) {
            repositories(first: 100, after: $afterCursor) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                nodes {
                    name
                    url
                }
            }
        }
    }
    """
    variables = {
        "orgLogin": org_login,
        "afterCursor": after_cursor
    }
    return query, variables
        

def write_public_repos_csv(data):
    print("Writing public repo list to file.")
    with open('public_repo_list.csv', mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['Organization', 'Repository', 'URL'])
        for row in data:
            writer.writerow(row)

    print("Successfully wrote to public_repo_list.csv")

def write_all_repos_csv(data):
    print("Writing all repo list to file.")
    with open('all_repo_list.csv', mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['Organization', 'Repository', 'URL'])
        for row in data:
            writer.writerow(row)

    print("Successfully wrote to all_repo_list.csv")

def create_public_repo_reports():
    
    org_counter = 0
    orgs = []
    has_next_page = True
    after_cursor = None
    while has_next_page:
        query, variables = get_all_orgs_query(after_cursor)
        result = run_query_with_vars(query, variables)
        orgs += result['data']['enterprise']['organizations']['nodes']
        has_next_page = result['data']['enterprise']['organizations']['pageInfo']['hasNextPage']
        after_cursor = result['data']['enterprise']['organizations']['pageInfo']['endCursor']

    data = []
    for org in orgs:
        org_counter += 1
        print("Getting data for org: ")
        print(org['name'], org_counter)

        has_next_page = True
        after_cursor = None
        while has_next_page:
            query, variables = get_all_public_repos_query(org['login'], after_cursor)
            result = run_query_with_vars(query, variables)
            repos = result['data']['organization']['repositories']['nodes']
            for repo in repos:
                data.append([org['name'], repo['name'], repo['url']])
            has_next_page = result['data']['organization']['repositories']['pageInfo']['hasNextPage']
            after_cursor = result['data']['organization']['repositories']['pageInfo']['endCursor']

    write_public_repos_csv(data)

def create_all_repo_reports():
    
    org_counter = 0
    orgs = []
    has_next_page = True
    after_cursor = None
    while has_next_page:
        query, variables = get_all_orgs_query(after_cursor)
        result = run_query_with_vars(query, variables)
        orgs += result['data']['enterprise']['organizations']['nodes']
        has_next_page = result['data']['enterprise']['organizations']['pageInfo']['hasNextPage']
        after_cursor = result['data']['enterprise']['organizations']['pageInfo']['endCursor']

    data = []
    for org in orgs:
        org_counter += 1
        print("Getting data for org: ")
        print(org['name'], org_counter)

        has_next_page = True
        after_cursor = None
        while has_next_page:
            query, variables = get_all_repos_query(org['login'], after_cursor)
            result = run_query_with_vars(query, variables)
            repos = result['data']['organization']['repositories']['nodes']
            for repo in repos:
                data.append([org['name'], repo['name'], repo['url']])
            has_next_page = result['data']['organization']['repositories']['pageInfo']['hasNextPage']
            after_cursor = result['data']['organization']['repositories']['pageInfo']['endCursor']

    write_all_repos_csv(data)
    
    
    
    return

def create_secrets_reports():

    org_counter = 0
    orgs = []
    has_next_page = True
    after_cursor = None
    while has_next_page:
        query, variables = get_all_orgs_query(after_cursor)
        result = run_query_with_vars(query, variables)
        orgs += result['data']['enterprise']['organizations']['nodes']
        has_next_page = result['data']['enterprise']['organizations']['pageInfo']['hasNextPage']
        after_cursor = result['data']['enterprise']['organizations']['pageInfo']['endCursor']

    data = []
    for org in orgs:
        print("creating secrets report for org: " + org['name'])
        output_file = "secrets_" + org['name'] + ".csv"

        subprocess.run(["gh", "export-secrets", "--output-file", output_file, org['name']])
    
        print("Done creating secrets report for org: " + org['name'])
    
    return

def create_repo_stats():

    
    orgs = []
    has_next_page = True
    after_cursor = None
    while has_next_page:
        query, variables = get_all_orgs_query(after_cursor)
        result = run_query_with_vars(query, variables)
        orgs += result['data']['enterprise']['organizations']['nodes']
        has_next_page = result['data']['enterprise']['organizations']['pageInfo']['hasNextPage']
        after_cursor = result['data']['enterprise']['organizations']['pageInfo']['endCursor']

    
    for org in orgs:
        print("creating repo stats report for org: " + org['name'])
        #output_file = "secrets_" + org['name'] + ".csv"

        orglogin = org['login']
        subprocess.run(["gh", "repo-stats", "-o", org['login']])
    
        print("Done creating repo stats report for org: " + org['name'])
    
    return

def create_environments_report():

    
    #orgs = []
    #has_next_page = True
    #after_cursor = None
    #while has_next_page:
    #    query, variables = get_all_orgs_query(after_cursor)
    #    result = run_query_with_vars(query, variables)
    #    orgs += result['data']['enterprise']['organizations']['nodes']
    #    has_next_page = result['data']['enterprise']['organizations']['pageInfo']['hasNextPage']
    #    after_cursor = result['data']['enterprise']['organizations']['pageInfo']['endCursor']

    
    #for org in orgs:
        
        # retrieve all repos for org
        # for each repo, retrieve all environments
        # for each environment, retrieve all secrets
          # Can do this using either Rest API or CLI

    headers2 = {
        'Authorization': 'Bearer ' + args.token,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28'
    }

    request = requests.post('https://api.github.com/orgs/mickeygoussetorg/repos', headers=headers2)
    # make a requests.post call to the github api 

    print(request)

    if request.status_code == 200:
        return request.json()
    else:
        raise Exception("API request failed with status code: {}".format(request.status_code))
   
    
    return


def main():

    if args.public_repos:
        print("Creating public repo report")
        create_public_repo_reports()
        print("Done creating public repo report")

    if args.all_repos:
        print("Creating all repo report")
        create_all_repo_reports()
        print("Done creating all repo report")

    if args.secrets:
        print("create secrets reports")
        create_secrets_reports()
        print("Done creating secrets reports")

    if args.repo_stats:
        print("create repo stats")
        create_repo_stats()
        print("Done creating repo stats")

    if args.environments:
        print("create environments report")
        create_environments_report()
        print("Done creating environments report")
    
if __name__ == '__main__':
    main()