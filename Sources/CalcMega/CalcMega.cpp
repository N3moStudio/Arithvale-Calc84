#include "CalcMega.h"
#include "megaapi.h"
#include <memory>
#include <string>
using namespace mega;

// These one-shot listeners live until the SDK's final callback, including errors.
// Result strings are copied by Swift before the callback returns.
struct Request final : MegaRequestListener {
    C84MegaCallback callback; void *context; bool session;
    Request(C84MegaCallback cb, void *ctx, bool dump = false) : callback(cb), context(ctx), session(dump) {}
    void onRequestFinish(MegaApi *api, MegaRequest *, MegaError *error) override {
        std::unique_ptr<char[]> value(session && error->getErrorCode() == MegaError::API_OK ? api->dumpSession() : nullptr);
        callback(context, error->getErrorCode(), value ? value.get() : ""); delete this;
    }
};
struct Transfer final : MegaTransferListener {
    C84MegaCallback callback; void *context; int temporaryCode = 0;
    Transfer(C84MegaCallback cb, void *ctx) : callback(cb), context(ctx) {}
    void onTransferFinish(MegaApi *, MegaTransfer *, MegaError *error) override {
        callback(context, temporaryCode ? temporaryCode : error->getErrorCode(), ""); delete this;
    }
    void onTransferTemporaryError(MegaApi *api, MegaTransfer *transfer, MegaError *error) override {
        if (error->getErrorCode() == MegaError::API_EOVERQUOTA || error->getErrorCode() == MegaError::API_EGOINGOVERQUOTA) {
            temporaryCode = error->getErrorCode(); api->cancelTransfer(transfer);
        }
    }
};
static MegaApi *api(void *client) { return static_cast<MegaApi *>(client); }
extern "C" {
void *c84mega_create(const char *key) {
    // No plaintext node database or session cache. The session goes in Keychain.
    MegaApi::setLogLevel(-1);
    auto client = new MegaApi(key, static_cast<const char *>(nullptr), "Calc84/0.3");
    client->useHttpsOnly(true); client->setPublicKeyPinning(true); client->retrySSLerrors(false);
    return client;
}
void c84mega_destroy(void *client) { delete api(client); }
void c84mega_login(void *client, const char *email, const char *password, const char *code, C84MegaCallback cb, void *ctx) {
    auto listener = new Request(cb, ctx, true);
    if (code && *code) api(client)->multiFactorAuthLogin(email, password, code, listener);
    else api(client)->login(email, password, listener);
}
void c84mega_resume(void *client, const char *session, C84MegaCallback cb, void *ctx) { api(client)->fastLogin(session, new Request(cb, ctx)); }
void c84mega_fetch(void *client, C84MegaCallback cb, void *ctx) { api(client)->fetchNodes(new Request(cb, ctx)); }
void c84mega_mkdir(void *client, const char *parent, const char *name, C84MegaCallback cb, void *ctx) {
    std::unique_ptr<MegaNode> node(api(client)->getNodeByPath(parent));
    if (!node) { cb(ctx, MegaError::API_ENOENT, ""); return; }
    std::unique_ptr<MegaNode> existing(api(client)->getChildNode(node.get(), name));
    if (existing) { cb(ctx, existing->isFolder() ? 0 : MegaError::API_EEXIST, ""); return; }
    api(client)->createFolder(name, node.get(), new Request(cb, ctx));
}
int64_t c84mega_size(void *client, const char *path) {
    std::unique_ptr<MegaNode> node(api(client)->getNodeByPath(path));
    return node && node->isFile() ? node->getSize() : -1;
}
void c84mega_list(void *client, C84MegaCallback cb, void *ctx) {
    std::unique_ptr<MegaNode> root(api(client)->getNodeByPath("/c84/v1"));
    if (!root) { cb(ctx, 0, ""); return; }
    std::string result;
    std::unique_ptr<MegaNodeList> libraries(api(client)->getChildren(root.get()));
    for (int i = 0; i < libraries->size(); ++i) {
        auto library = libraries->get(i);
        if (!library->isFolder()) continue;
        std::unique_ptr<MegaNode> folder(api(client)->getChildNode(library, "snapshots"));
        if (!folder || !folder->isFolder()) continue;
        std::unique_ptr<MegaNodeList> files(api(client)->getChildren(folder.get()));
        for (int j = 0; j < files->size(); ++j) {
            auto file = files->get(j);
            if (!file->isFile()) continue;
            std::string name(file->getName());
            if (name.size() != 45 || name.substr(36) != ".c84cloud") continue;
            result += "c84/v1/" + std::string(library->getName()) + "/snapshots/" + name + "\n";
            if (result.size() > 1024 * 1024) { cb(ctx, MegaError::API_ETOOMANY, ""); return; }
        }
    }
    cb(ctx, 0, result.c_str());
}
void c84mega_upload(void *client, const char *local, const char *parent, const char *name, C84MegaCallback cb, void *ctx) {
    std::unique_ptr<MegaNode> node(api(client)->getNodeByPath(parent));
    if (!node) { cb(ctx, MegaError::API_ENOENT, ""); return; }
    api(client)->startUpload(local, node.get(), name, -1, nullptr, false, false, nullptr, new Transfer(cb, ctx));
}
void c84mega_download(void *client, const char *path, const char *local, C84MegaCallback cb, void *ctx) {
    std::unique_ptr<MegaNode> node(api(client)->getNodeByPath(path));
    if (!node) { cb(ctx, MegaError::API_ENOENT, ""); return; }
    api(client)->startDownload(node.get(), local, nullptr, nullptr, false, nullptr, 0, 0, false, new Transfer(cb, ctx));
}
void c84mega_cancel(void *client) {
    api(client)->cancelTransfers(MegaTransfer::TYPE_UPLOAD);
    api(client)->cancelTransfers(MegaTransfer::TYPE_DOWNLOAD);
}
}
