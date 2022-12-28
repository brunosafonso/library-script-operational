def call() {
    modules = ["service","service-history"]
    for (int i = 0; i < modules.size(); i++) {
        sh """
            echo ${modules[i]}
        """
    }
}