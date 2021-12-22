import boto3
import sys

if __name__ == "__main__":
    print("Hello from rules_container.")
    print("Python version: %s" % sys.version)
    print("Boto3 version from pip_install: %s" % boto3.__version__)