def call() {
	multi_service = ["service","service-history"]
    for (int i = 0; i < modules.size(); i++) {
        sh """
            echo ${config.dir}
            echo ${modules[i]}
        """
    }
}