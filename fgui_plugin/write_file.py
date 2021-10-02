
class FileDeal:
    def __init__(self, name, mode):
        self.file = open(name, mode)

    def write(self,msg):
        msg = str(msg)
        self.file.write(msg)

    def writeLine(self,msg):
        msg = str(msg) + "\n"
        self.file.write(msg)

    def save(self):
        self.file.close()
