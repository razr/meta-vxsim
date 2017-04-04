# hardcode the version for a while
def get_kernelversion_headers(p):
    return "7.0.0.0"

def get_kernelversion_file(p):
    fn = p + '/version.h'

    try:
        with open(fn, 'r') as f:
            return f.readlines()[0].strip()
    except IOError:
        return None

# that's all

