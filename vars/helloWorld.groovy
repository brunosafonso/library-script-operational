def call(Map config = [:]) {
    modules = ["service","service-history"]
    for (int i = 0; i < modules.size(); i++) {
        sh """
            echo ${modules[i]}
            echo ${config.dir}
            echo ${infra_dir}
        """
    }
}