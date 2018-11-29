//=================================================================================================
//      Copyright HighJump Software Inc.
//      All Rights Reserved.
//
//      For a complete copyright notice, see "HighJump Copyright.pdf" in the Dev folder.
//=================================================================================================

module HighJump.Platform.Admin.Common.Services {
    export interface IDownloadService {
        download(url: string): JQueryPromise<void>;
    }

    export class DownloadService implements IDownloadService {
        constructor(private _localizedStrings: Localization.ILocalizedStrings) {
        }

        download(url: string): JQueryPromise<void> {
            return this.downloadInPopupWindow(url);
        }
        
        private downloadInPopupWindow(url: string): JQueryPromise<void> {
            var deferred = $.Deferred<void>();

            var checkTimeout = 100;
            var timeoutHandle: number;
            var downloadPopup = window.open(url);

            var cleanUp = () => {
                if (downloadPopup && !downloadPopup.closed) {
                    downloadPopup.close();
                }
                if (timeoutHandle) {
                    clearTimeout(timeoutHandle);
                }
            };
            var errorAccessRetryCount = 0;
            var checkDownloadComplete = () => {
                if (downloadPopup.closed) {
                    deferred.resolve();
                    cleanUp();

                    return;
                }
                else {
                    try {
                        var downloadDocument = downloadPopup.document;
                        if (downloadDocument && downloadDocument.body !== null && downloadDocument.body.innerHTML.length > 0) {
                            var errorRawMessage = hj.Utils.format(this._localizedStrings.assets.exportUnableToRequestUrlErrorMessage, url);
                            errorRawMessage += "\r\n";
                            errorRawMessage += $(downloadDocument).text();
                            deferred.reject({ raw: errorRawMessage });
                            cleanUp();
                        }
                        else {
                            timeoutHandle = setTimeout(checkDownloadComplete, checkTimeout);
                        }
                    }
                    catch (error) {
                        if (errorAccessRetryCount > 10) {
                            deferred.reject({ raw: error });
                            cleanUp();

                            return;
                        }
                        else {
                            errorAccessRetryCount++;
                            timeoutHandle = setTimeout(checkDownloadComplete, checkTimeout);
                        }
                    }
                }
            };

            if (!downloadPopup) {
                deferred.reject({ message: this._localizedStrings.assets.exportEnablePopupBlockerMessage });
            }
            else {
                timeoutHandle = setTimeout(checkDownloadComplete, checkTimeout);
            }

            return deferred.promise();
        }

        //this method it has visual advantage to download a file in a background without opening new window.
        //But it doen't work well cross all devices.
        private downloadInIframe(url: string): JQueryPromise<void> {
            var deferred = $.Deferred<void>();

            var $downloadIframe = $("<iframe>")
                .hide()
                .prop("src", url)
                .appendTo("body");

            var cleanUp = () => {
                if ($downloadIframe) {
                    $downloadIframe.remove();
                }
            };

            var onDownloadIframeLoaded = () => {
                try {
                    var downloadIframe: any = $downloadIframe[0];
                    var downloadDocument = downloadIframe.contentWindow || downloadIframe.contentDocument;
                    if (downloadDocument.document) {
                        downloadDocument = downloadDocument.document;
                    }

                    if (downloadDocument && downloadDocument.body !== null && downloadDocument.body.innerHTML.length > 0) {
                        deferred.reject($(downloadDocument).text());
                        cleanUp();
                    }
                    else {
                        deferred.resolve();
                        cleanUp();
                    }
                }
                catch (error) {
                    deferred.reject(error);
                    cleanUp();
                }
            };

            $downloadIframe.on("load", onDownloadIframeLoaded);

            return deferred.promise();
        }
    }
}
