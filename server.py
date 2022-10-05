#!/usr/bin/env python3
import connexion

def health() -> str:
    return 'ok\n'

app = connexion.FlaskApp(__name__, specification_dir='openapi/')

# Create a URL route in our application for "/"
@app.route('/')
def default() -> str:
    return 'Pydgraph Client Utility.\nSee supported API with http(s)://<server_hostname>:<port>/ui. \n'

# If running in stand alone mode, run the application
if __name__ == '__main__':
    app.add_api('api.yaml', arguments={'title': 'Pydgraph Client'})
    app.run(host='0.0.0.0', port=5000, debug=False)
